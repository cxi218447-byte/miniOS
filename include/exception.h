#ifndef MINIOS_EXCEPTION_H
#define MINIOS_EXCEPTION_H

void exception_init(void);
void exception_handler(unsigned long estat, unsigned long era);

#endif
