#include "mconfig.h"
#include <ctype.h>

static void trim(char *str) {
  char *start = str;
  while (isspace((unsigned char)*start)) start++;
  char *end = start + strlen(start) - 1;
  while (end > start && isspace((unsigned char)*end)) end--;
  *(end + 1) = '\0';
  if (start != str)
    memmove(str, start, end - start + 2);
}

static char* read_quoted(char *str) {
  char *p = str;
  if (*p == '"') p++;
  char *end = p + strlen(p) - 1;
  if (end > p && *end == '"') *end = '\0';
  return p;
}

static void add_item(menu_t *menu, void *data, int type) {
  if (menu->item_count >= menu->item_capacity) {
    menu->item_capacity = menu->item_capacity ? menu->item_capacity * 2 : 8;
    menu->items = realloc(menu->items, menu->item_capacity * sizeof(struct menu_item));
  }
  menu->items[menu->item_count].type = type;
  if (type == ITEM_OPTION)
    menu->items[menu->item_count].data.option = (config_option_t*)data;
  else
    menu->items[menu->item_count].data.submenu = (menu_t*)data;
  menu->item_count++;
}

static config_option_t* new_option(const char *name) {
  config_option_t *opt = calloc(1, sizeof(config_option_t));
  strncpy(opt->name, name, MAX_NAME-1);
  opt->type = TYPE_BOOL;
  opt->value.bool_val = 0;   // default n
  opt->visible = 1;
  return opt;
}

static menu_t* new_menu(const char *title) {
  menu_t *menu = calloc(1, sizeof(menu_t));
  strncpy(menu->title, title, MAX_DESC-1);
  return menu;
}

static void parse_properties(FILE *fp, config_option_t *opt) {
  char line[MAX_DESC];
  int in_help = 0;
  long pos;
  while (1) {
    pos = ftell(fp);
    if (!fgets(line, sizeof(line), fp)) break;
    trim(line);
    if (line[0] == '\0') {
      in_help = 0;
      continue;
    }
    if (strncmp(line, "config", 6) == 0 ||
        strncmp(line, "menu", 4) == 0 ||
        strncmp(line, "endmenu", 7) == 0) {
      fseek(fp, pos, SEEK_SET);
      break;
    }
    if (in_help) {
      if (line[0] == '\0') in_help = 0;
      continue;
    }
    if (strncmp(line, "help", 4) == 0) {
      in_help = 1;
      continue;
    }
    if (strncmp(line, "bool", 4) == 0) {
      opt->type = TYPE_BOOL;
      char *desc = line + 4;
      trim(desc);
      if (*desc == '"') {
        desc = read_quoted(desc);
      }
      strncpy(opt->desc, desc, MAX_DESC-1);
    } else if (strncmp(line, "string", 6) == 0) {
      opt->type = TYPE_STRING;
      char *desc = line + 6;
      trim(desc);
      if (*desc == '"') desc = read_quoted(desc);
      strncpy(opt->desc, desc, MAX_DESC-1);
      opt->value.string_val[0] = '\0';
    } else if (strncmp(line, "default", 7) == 0) {
      char *val = line + 7;
      trim(val);
      if (opt->type == TYPE_BOOL) {
        if (strcmp(val, "y") == 0) opt->value.bool_val = 1;
        else opt->value.bool_val = 0;
      } else { // string
        if (*val == '"') val = read_quoted(val);
        strncpy(opt->value.string_val, val, MAX_STRING_VAL-1);
      }
    } else if (strncmp(line, "depends", 7) == 0) {
      char *dep = line + 7;
      if (strncmp(dep, "on", 2) == 0) dep += 2;
      trim(dep);
      strncpy(opt->depends, dep, MAX_DEP-1);
    }
  }
}

static void parse_menu(FILE *fp, menu_t *current) {
  char line[MAX_DESC];
  while (fgets(line, sizeof(line), fp)) {
    trim(line);
    if (strncmp(line, "endmenu", 7) == 0) break;
    if (strncmp(line, "menu", 4) == 0) {
      char *title = line + 4;
      trim(title);
      if (*title == '"') title = read_quoted(title);
      menu_t *sub = new_menu(title);
      add_item(current, sub, ITEM_MENU);
      parse_menu(fp, sub);
    } else if (strncmp(line, "config", 6) == 0) {
      char *name = line + 6;
      trim(name);
      config_option_t *opt = new_option(name);
      parse_properties(fp, opt);
      add_item(current, opt, ITEM_OPTION);
    }
  }
}

menu_t* parse_kconfig(const char *filename) {
  FILE *fp = fopen(filename, "r");
  if (!fp) {
    fprintf(stderr, "Cannot open %s\n", filename);
    exit(1);
  }
  menu_t *root = new_menu("Main Menu");
  parse_menu(fp, root);
  fclose(fp);
  return root;
}

void free_menu(menu_t *menu) {
  for (int i = 0; i < menu->item_count; i++) {
    if (menu->items[i].type == ITEM_OPTION)
      free(menu->items[i].data.option);
    else
      free_menu(menu->items[i].data.submenu);
  }
  free(menu->items);
  free(menu);
}
