#include <errno.h>
int
__get_errno(void)
{
  return errno;
}
