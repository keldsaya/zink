#include "mconfig.h"

int main() {
  menu_t *root = parse_kconfig("Kconfig");
  load_config_values(root, ".config");
  update_visibility(root);
  run_ui(root);
  free_menu(root);
  return 0;
}
