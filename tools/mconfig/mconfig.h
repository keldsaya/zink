#ifndef TYPES_H
#define TYPES_H

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define MAX_NAME    64
#define MAX_DESC    256
#define MAX_DEP     64
#define MAX_STRING_VAL 128

typedef enum {
  TYPE_BOOL,
  TYPE_STRING
} config_type_t;

typedef struct config_option {
  char name[MAX_NAME];
  config_type_t type;
  union {
    int bool_val;          // 0 = n, 1 = y
    char string_val[MAX_STRING_VAL];
  } value;
  char desc[MAX_DESC];
  char depends[MAX_DEP];
  int visible;             
} config_option_t;

typedef struct menu {
  char title[MAX_DESC];
  struct menu_item {
    enum { ITEM_OPTION, ITEM_MENU } type;
    union {
      config_option_t *option;
      struct menu *submenu;
    } data;
  } *items;
  int item_count;
  int item_capacity;
} menu_t;

menu_t* parse_kconfig(const char *filename);
void free_menu(menu_t *menu);

void load_config_values(menu_t *menu, const char *filename);
void save_config_values(menu_t *menu, const char *filename);

void update_visibility(menu_t *root);
void run_ui(menu_t *root_menu);
int getkey(void);

#endif /* TYPES_H */
