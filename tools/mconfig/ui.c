#include "mconfig.h"
#include <unistd.h>
#include <termios.h>
#include <sys/select.h>
#include <sys/time.h>
#include <sys/ioctl.h>

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
  raw.c_cc[VMIN] = 1;
  raw.c_cc[VTIME] = 0;
  tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw);
}

int getkey() {
  char c;
  if (read(STDIN_FILENO, &c, 1) != 1) return -1;

  if (c == '\033') {
    struct timeval tv = {0, 50000}; // 50ms timeout
    fd_set fds;
    FD_ZERO(&fds);
    FD_SET(STDIN_FILENO, &fds);
    
    if (select(STDIN_FILENO + 1, &fds, NULL, NULL, &tv) > 0) {
      char seq[2];
      if (read(STDIN_FILENO, &seq[0], 1) != 1) return 27;
      if (read(STDIN_FILENO, &seq[1], 1) != 1) return 27;
      
      if (seq[0] == '[') {
        switch (seq[1]) {
          case 'A': return 65;  // Up arrow
          case 'B': return 66;  // Down arrow
          case 'C': return 67;  // Right arrow
          case 'D': return 68;  // Left arrow
        }
      }
      return 27;
    } else {
      return 27;
    }
  }
  return c;
}

void clear_screen() {
  printf("\033[2J\033[H");
  fflush(stdout);
}

static int get_terminal_height() {
  struct winsize w;
  if (ioctl(STDOUT_FILENO, TIOCGWINSZ, &w) == 0) {
    return w.ws_row;
  }
  return 24; // Default
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

static int edit_string(config_option_t *opt) {
  char buf[MAX_STRING_VAL];
  strcpy(buf, opt->value.string_val);
  int pos = strlen(buf);

  disable_raw_mode();
  clear_screen();

  printf("Edit string: %s\n", opt->desc);
  printf("Current value: %s\n\n", buf);
  printf("[Enter] to save, [Esc] to cancel, backspace to delete\n");
  printf("\n> ");
  fflush(stdout);

  printf("%s", buf);
  fflush(stdout);
  
  enable_raw_mode();

  while (1) {
    int c = getkey();
    if (c == 27) { 
      disable_raw_mode();
      return 0; 
    } else if (c == '\n' || c == '\r') { // Enter - сохранить
      strncpy(opt->value.string_val, buf, MAX_STRING_VAL-1);
      opt->value.string_val[MAX_STRING_VAL-1] = '\0';
      disable_raw_mode();
      return 1; 
    } else if (c == 127 || c == '\b') { // Backspace
      if (pos > 0) {
        pos--;
        buf[pos] = '\0';
        printf("\b \b");
        fflush(stdout);
      }
    } else if (c >= 32 && c < 127 && pos < MAX_STRING_VAL-1) {
      buf[pos++] = c;
      buf[pos] = '\0';
      putchar(c);
      fflush(stdout);
    } else if (c == 1) { // Ctrl+A
    } else if (c == 5) { // Ctrl+E 
    }
  }
}

static void draw_menu(menu_t *menu, int cursor, int scroll, int term_height) {
  clear_screen();
  
  int header_lines = 5;  // Title + separators
  int footer_lines = 4;  // Status line + separator + description + key help
  int max_items = term_height - header_lines - footer_lines;
  if (max_items < 1) max_items = 5;
  
  typedef struct { 
    void *ptr; 
    int type; 
  } vis_item;
  vis_item vis[256];
  int vis_cnt = 0;
  
  for (int i = 0; i < menu->item_count && vis_cnt < 256; i++) {
    if (menu->items[i].type == ITEM_MENU) {
      vis[vis_cnt].type = ITEM_MENU;
      vis[vis_cnt].ptr = menu->items[i].data.submenu;
      vis_cnt++;
    } else {
      config_option_t *opt = menu->items[i].data.option;
      if (opt->visible) {
        vis[vis_cnt].type = ITEM_OPTION;
        vis[vis_cnt].ptr = opt;
        vis_cnt++;
      }
    }
  }
  
  if (cursor >= vis_cnt) cursor = vis_cnt - 1;
  if (cursor < 0 && vis_cnt > 0) cursor = 0;
  if (scroll > cursor) scroll = cursor;
  if (cursor >= scroll + max_items) scroll = cursor - max_items + 1;
  if (scroll < 0) scroll = 0;
  
  if (cmd_mode) {
    printf(":%s\n", cmd_buf);
  } else {
    printf("\n");
  }
  printf("----------------------------------------------------------------------\n");
  printf("Menu: %s\n", menu->title);
  printf("----------------------------------------------------------------------\n");
  
  int end = scroll + max_items;
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
        printf("%-32s = %c\n", opt->name, opt->value.bool_val ? 'y' : 'n');
      } else {
        printf("%-32s = \"%s\"\n", opt->name, opt->value.string_val);
      }
    }
  }
  
  printf("----------------------------------------------------------------------\n");
  
  if (cursor >= 0 && cursor < vis_cnt) {
    if (vis[cursor].type == ITEM_OPTION) {
      config_option_t *opt = (config_option_t*)vis[cursor].ptr;
      printf("%s\n", opt->desc);
    } else if (vis[cursor].type == ITEM_MENU) {
      printf("Enter this submenu\n");
    }
  }
  
  printf("----------------------------------------------------------------------\n");
  printf(":q  :wq  :w  :r  |  j/k up/down  |  Enter=select/edit  |  Esc=back\n");
  
  if (vis_cnt > max_items) {
    printf("[%d-%d of %d]  ", scroll+1, end, vis_cnt);
  }
  
  fflush(stdout);
}
void run_ui(menu_t *root_menu) {
  enable_raw_mode();
  menu_t *stack[32];
  int stack_ptr = 0;
  stack[0] = root_menu;
  int cursor = 0, scroll = 0;
  int need_redraw = 1;

  while (1) {
    if (need_redraw) {
      int term_height = get_terminal_height();
      menu_t *cur = stack[stack_ptr];
      draw_menu(cur, cursor, scroll, term_height);
      need_redraw = 0;
    }

    int c = getkey();
    if (c == -1) continue;

    menu_t *cur = stack[stack_ptr];
    int term_height = get_terminal_height();
    int header_lines = 5;
    int footer_lines = 4;
    int max_items = term_height - header_lines - footer_lines;
    if (max_items < 1) max_items = 5;

    typedef struct { void *ptr; int type; } vis_item;
    vis_item vis[256];
    int vis_cnt = 0;

    for (int i = 0; i < cur->item_count && vis_cnt < 256; i++) {
      if (cur->items[i].type == ITEM_MENU) {
        vis[vis_cnt].type = ITEM_MENU;
        vis[vis_cnt].ptr = cur->items[i].data.submenu;
        vis_cnt++;
      } else {
        config_option_t *opt = cur->items[i].data.option;
        if (opt->visible) {
          vis[vis_cnt].type = ITEM_OPTION;
          vis[vis_cnt].ptr = opt;
          vis_cnt++;
        }
      }
    }

    if (c == 27) { // ESC
      if (cmd_mode) {
        cmd_mode = 0;
        cmd_buf[0] = '\0';
        cmd_pos = 0;
        need_redraw = 1;
      } else if (stack_ptr > 0) {
        stack_ptr--;
        cursor = 0;
        scroll = 0;
        update_visibility(root_menu);
        need_redraw = 1;
      }
    } else if (cmd_mode) {
      if (c == '\n' || c == '\r') {
        cmd_buf[cmd_pos] = '\0';
        if (strcmp(cmd_buf, "q") == 0) {
          break;
        } else if (strcmp(cmd_buf, "wq") == 0) {
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
        need_redraw = 1;
      } else if (c == 127 || c == '\b') {
        if (cmd_pos > 0) {
          cmd_buf[--cmd_pos] = '\0';
        }
        need_redraw = 1;
      } else if (c >= 32 && c <= 126 && cmd_pos < 15) {
        cmd_buf[cmd_pos++] = c;
        cmd_buf[cmd_pos] = '\0';
        need_redraw = 1;
      }
    } else {
      if (c == ':') {
        cmd_mode = 1;
        cmd_pos = 0;
        cmd_buf[0] = '\0';
        need_redraw = 1;
      } else if (c == 'j' || c == 's' || c == 66) { // Down
        if (cursor < vis_cnt - 1) {
          cursor++;
          if (cursor >= scroll + max_items) scroll = cursor - max_items + 1;
          need_redraw = 1;
        }
      } else if (c == 'k' || c == 'w' || c == 65) { // Up
        if (cursor > 0) {
          cursor--;
          if (cursor < scroll) scroll = cursor;
          need_redraw = 1;
        }
      } else if (c == '\n' || c == '\r') { // Enter
        if (vis_cnt == 0) continue;
        if (vis[cursor].type == ITEM_MENU) {
          if (stack_ptr < 31) {
            stack[++stack_ptr] = (menu_t*)vis[cursor].ptr;
            cursor = 0;
            scroll = 0;
            need_redraw = 1;
          }
        } else {
          config_option_t *opt = (config_option_t*)vis[cursor].ptr;
          if (opt->type == TYPE_BOOL) {
            opt->value.bool_val = !opt->value.bool_val;
            update_visibility(root_menu);
            need_redraw = 1;
          } else {
            disable_raw_mode();
            edit_string(opt);
            enable_raw_mode();
            update_visibility(root_menu);
            need_redraw = 1;
          }
        }
      }
    }
  }

  disable_raw_mode();
  clear_screen();
}
