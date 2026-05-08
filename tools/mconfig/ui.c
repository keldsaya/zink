#include "mconfig.h"
#include <unistd.h>
#include <termios.h>
#include <sys/select.h>
#include <sys/time.h>

static struct termios orig_termios;
static int cmd_mode = 0;
static char cmd_buf[16];
static int cmd_pos = 0;

void disable_raw_mode() {
  tcsetattr(STDIN_FILENO, TCSAFLUSH, &orig_termios);
}

void enable_raw_mode() {
  tcgetattr(STDIN_FILENO, &orig_termios);
  atexit(disable_raw_mode);
  struct termios raw = orig_termios;
  raw.c_lflag &= ~(ECHO | ICANON);
  raw.c_cc[VMIN] = 0;
  raw.c_cc[VTIME] = 1;
  tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw);
}

int getkey() {
  char c;
  if (read(STDIN_FILENO, &c, 1) != 1) return -1;

  if (c == '\033') {
    char seq[2];
    if (read(STDIN_FILENO, &seq[0], 1) != 1) return 27;
    if (read(STDIN_FILENO, &seq[1], 1) != 1) return 27;

    if (seq[0] == '[') {
      switch (seq[1]) {
        case 'A': return 65;
        case 'B': return 66;
        case 'C': return 67;
        case 'D': return 68;
      }
    }
    return 27;
  }
  return c;
}

void clear_screen() {
  printf("\033[2J\033[H");
}

static int find_option_bool(menu_t *root, const char *name) {
  for (int i = 0; i < root->item_count; i++) {
    if (root->items[i].type == ITEM_OPTION) {
      config_option_t *opt = root->items[i].data.option;
      if (strcmp(opt->name, name) == 0 && opt->type == TYPE_BOOL)
        return opt->value.bool_val;
    } else {
      int res = find_option_bool(root->items[i].data.submenu, name);
      if (res != -1) return res;
    }
  }
  return -1;
}

void update_visibility(menu_t *root) {
  for (int i = 0; i < root->item_count; i++) {
    if (root->items[i].type == ITEM_OPTION) {
      config_option_t *opt = root->items[i].data.option;
      if (opt->depends[0] == '\0') {
        opt->visible = 1;
      } else {
        int dep_val = find_option_bool(root, opt->depends);
        opt->visible = (dep_val == 1);
      }
    } else {
      update_visibility(root->items[i].data.submenu);
    }
  }
}

static void edit_string(config_option_t *opt) {
  char buf[MAX_STRING_VAL];
  strcpy(buf, opt->value.string_val);
  int pos = strlen(buf);
  clear_screen();
  printf("Edit string: %s\n", opt->desc);
  printf("Value: %s\n", buf);
  printf("\n[Enter] to save, [Esc] to cancel, backspace to delete\n");
  while (1) {
    int c = getkey();
    if (c == -1) continue;
    if (c == 27) {
      return;
    } else if (c == '\n' || c == '\r') {
      strncpy(opt->value.string_val, buf, MAX_STRING_VAL-1);
      opt->value.string_val[MAX_STRING_VAL-1] = '\0';
      return;
    } else if (c == 127 || c == '\b') {
      if (pos > 0) {
        pos--;
        buf[pos] = '\0';
      }
    } else if (c >= 32 && c < 127 && pos < MAX_STRING_VAL-1) {
      buf[pos++] = c;
      buf[pos] = '\0';
    }
    printf("\033[1A\033[2K\r");
    printf("Value: %s\n", buf);
  }
}

static void draw_menu(menu_t *menu, int cursor, int scroll, int height) {
  clear_screen();
  if (cmd_mode) {
    printf(":%s\n", cmd_buf);
  } else {
    printf("\n");
  }
  printf("----------------------------------------------------------------------\n");
  printf("Menu: %s\n", menu->title);
  printf("----------------------------------------------------------------------\n");

  typedef struct { int idx; void *ptr; int type; } vis_item;
  vis_item vis[256];
  int vis_cnt = 0;
  for (int i = 0; i < menu->item_count; i++) {
    if (menu->items[i].type == ITEM_MENU) {
      vis[vis_cnt].idx = i;
      vis[vis_cnt].type = ITEM_MENU;
      vis[vis_cnt].ptr = menu->items[i].data.submenu;
      vis_cnt++;
    } else {
      config_option_t *opt = menu->items[i].data.option;
      if (opt->visible) {
        vis[vis_cnt].idx = i;
        vis[vis_cnt].type = ITEM_OPTION;
        vis[vis_cnt].ptr = opt;
        vis_cnt++;
      }
    }
  }

  int end = scroll + height;
  if (end > vis_cnt) end = vis_cnt;
  for (int i = scroll; i < end; i++) {
    if (i == cursor && !cmd_mode)
      printf("# ");
    else
      printf("  ");
    if (vis[i].type == ITEM_MENU) {
      menu_t *sub = (menu_t*)vis[i].ptr;
      printf("%-32s --->\n", sub->title);
    } else {
      config_option_t *opt = (config_option_t*)vis[i].ptr;
      if (opt->type == TYPE_BOOL) {
        printf("%-32s = %s\n", opt->name, opt->value.bool_val ? "y" : "n");
      } else {
        printf("%-32s = \"%s\"\n", opt->name, opt->value.string_val);
      }
    }
  }
  if (vis_cnt > height) {
    printf("\n[%d-%d of %d]\n", scroll+1, end, vis_cnt);
  }
  printf("----------------------------------------------------------------------\n");
  if (cursor < vis_cnt && vis[cursor].type == ITEM_OPTION) {
    config_option_t *opt = (config_option_t*)vis[cursor].ptr;
    printf("%s\n", opt->desc);
  } else if (cursor < vis_cnt && vis[cursor].type == ITEM_MENU) {
    printf("Enter this submenu\n");
  } else {
    printf("No description\n");
  }
  printf("----------------------------------------------------------------------\n");
  printf(":q  :wq  :w  :r  |  j/k up/down  |  Enter=select/edit  |  Esc=back\n");
}

void run_ui(menu_t *root_menu) {
  enable_raw_mode();
  menu_t *stack[32];
  int stack_ptr = 0;
  stack[0] = root_menu;
  int cursor = 0, scroll = 0;
  int height = 18;

  while (1) {
    menu_t *cur = stack[stack_ptr];

    typedef struct { int orig_idx; void *ptr; int type; } vis_item;
    vis_item vis[256];
    int vis_cnt = 0;
    for (int i = 0; i < cur->item_count; i++) {
      if (cur->items[i].type == ITEM_MENU) {
        vis[vis_cnt].orig_idx = i;
        vis[vis_cnt].type = ITEM_MENU;
        vis[vis_cnt].ptr = cur->items[i].data.submenu;
        vis_cnt++;
      } else {
        config_option_t *opt = cur->items[i].data.option;
        if (opt->visible) {
          vis[vis_cnt].orig_idx = i;
          vis[vis_cnt].type = ITEM_OPTION;
          vis[vis_cnt].ptr = opt;
          vis_cnt++;
        }
      }
    }
    if (cursor >= vis_cnt) cursor = vis_cnt - 1;
    if (cursor < 0 && vis_cnt > 0) cursor = 0;
    if (scroll > cursor) scroll = cursor;
    if (cursor >= scroll + height) scroll = cursor - height + 1;

    draw_menu(cur, cursor, scroll, height);

    int c = getkey();
    if (c == -1) continue;

    if (c == 27) {
      if (cmd_mode) {
        cmd_mode = 0;
        cmd_buf[0] = '\0';
        cmd_pos = 0;
      } else if (stack_ptr > 0) {
        stack_ptr--;
        cursor = 0; scroll = 0;
      }
    } else if (cmd_mode) {
      if (c == '\n' || c == '\r') {
        cmd_buf[cmd_pos] = '\0';
        if (strcmp(cmd_buf, "q") == 0) break;
        else if (strcmp(cmd_buf, "wq") == 0) {
          save_config_values(root_menu, ".config");
          break;
        } else if (strcmp(cmd_buf, "w") == 0) {
          save_config_values(root_menu, ".config");
        } else if (strcmp(cmd_buf, "r") == 0) {
          load_config_values(root_menu, ".config");
          update_visibility(root_menu);
        }
        cmd_mode = 0;
        cmd_pos = 0;
        cmd_buf[0] = '\0';
      } else if (c == 127 || c == '\b') {
        if (cmd_pos > 0) cmd_buf[--cmd_pos] = '\0';
      } else if (c >= 32 && c <= 126 && cmd_pos < 15) {
        cmd_buf[cmd_pos++] = c;
        cmd_buf[cmd_pos] = '\0';
      }
    } else {
      if (c == ':') {
        cmd_mode = 1;
        cmd_pos = 0;
        cmd_buf[0] = '\0';
      } else if (c == 'j' || c == 's' || c == 66) {
        if (cursor < vis_cnt - 1) cursor++;
      } else if (c == 'k' || c == 'w' || c == 65) {
        if (cursor > 0) cursor--;
      } else if (c == '\n' || c == '\r') {
        if (vis_cnt == 0) continue;
        if (vis[cursor].type == ITEM_MENU) {
          if (stack_ptr < 31) {
            stack[++stack_ptr] = (menu_t*)vis[cursor].ptr;
            cursor = 0; scroll = 0;
          }
        } else {
          config_option_t *opt = (config_option_t*)vis[cursor].ptr;
          if (opt->type == TYPE_BOOL) {
            opt->value.bool_val = !opt->value.bool_val;
            update_visibility(root_menu);
          } else {
            edit_string(opt);
            update_visibility(root_menu);
          }
        }
      }
    }
  }
  disable_raw_mode();
}
