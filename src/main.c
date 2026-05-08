#include <stdio.h>
#include "config.h"

#ifdef CONFIG_SAMPLE
void sample_feature();
#endif

int main(void) {
#ifdef CONFIG_SAMPLE
  sample_feature();
#else
  printf("Sample feature is disabled.\n");
#endif
  return 0;
}
