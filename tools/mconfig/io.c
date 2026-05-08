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

static void save_option(FILE *fp, config_option_t *opt) {
  if (opt->type == TYPE_BOOL) {
    fprintf(fp, "CONFIG_%s=%c\n", opt->name, opt->value.bool_val ? 'y' : 'n');
  } else { // string
    fprintf(fp, "CONFIG_%s=\"%s\"\n", opt->name, opt->value.string_val);
  }
}

static void save_recursive(menu_t *menu, FILE *fp) {
  for (int i = 0; i < menu->item_count; i++) {
    if (menu->items[i].type == ITEM_OPTION) {
      save_option(fp, menu->items[i].data.option);
    } else {
      save_recursive(menu->items[i].data.submenu, fp);
    }
  }
}

void save_config_values(menu_t *menu, const char *filename) {
  FILE *fp = fopen(filename, "w");
  if (!fp) {
    fprintf(stderr, "Cannot write %s\n", filename);
    return;
  }
  fprintf(fp, "# Lanex Kernel Configuration\n# Auto-generated\n\n");
  save_recursive(menu, fp);
  fclose(fp);
}

static void load_option(config_option_t *opt, const char *name, const char *val) {
  (void)name; // unused
  if (opt->type == TYPE_BOOL) {
    opt->value.bool_val = (val[0] == 'y');
  } else {
    if (val[0] == '"') {
      char tmp[MAX_STRING_VAL];
      strncpy(tmp, val + 1, MAX_STRING_VAL-1);
      tmp[strcspn(tmp, "\"")] = '\0';
      strncpy(opt->value.string_val, tmp, MAX_STRING_VAL-1);
    } else {
      strncpy(opt->value.string_val, val, MAX_STRING_VAL-1);
    }
  }
}

static void load_recursive(menu_t *menu, const char *filename) {
  FILE *fp = fopen(filename, "r");
  if (!fp) return;
  char line[MAX_DESC];
  while (fgets(line, sizeof(line), fp)) {
    line[strcspn(line, "\n")] = 0;
    if (line[0] == '#' || line[0] == '\0') continue;
    char *eq = strchr(line, '=');
    if (!eq) continue;
    *eq = '\0';
    char *name = line;
    char *val = eq + 1;
    trim(name); trim(val);
    if (strncmp(name, "CONFIG_", 7) == 0) name += 7;
    // find option recursively
    for (int i = 0; i < menu->item_count; i++) {
      if (menu->items[i].type == ITEM_OPTION) {
        if (strcmp(menu->items[i].data.option->name, name) == 0) {
          load_option(menu->items[i].data.option, name, val);
          break;
        }
      } else {
        load_recursive(menu->items[i].data.submenu, filename);
      }
    }
  }
  fclose(fp);
}

void load_config_values(menu_t *menu, const char *filename) {
  load_recursive(menu, filename);
}
