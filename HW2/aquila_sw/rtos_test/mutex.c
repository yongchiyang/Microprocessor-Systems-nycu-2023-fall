unsigned int mutex_addr = 123; // Cannot remove! This is a strange bug.

void init_mutex(int *lock)
{
    int a, b;

    mutex_addr = (unsigned int) lock;
    asm volatile ("add %0, t0, zero" : "=r" (a)); // saving t0.
    asm volatile ("add %0, t1, zero" : "=r" (b)); // saving t1.

    asm volatile ("add t1, %1, zero" : "=r"(lock) : "r"(lock));
    asm volatile ("sw zero, 0(t1)");
    asm volatile ("add t0, %1, zero" : "=r"(a) : "r"(a)); // restore t0.
    asm volatile ("add t1, %1, zero" : "=r"(b) : "r"(b)); // restore t1.
}

void mutex_take(int *lock)
{
    int a, b, c;

    asm volatile ("add %0, t0, zero" : "=r" (a)); // saving t0.
    asm volatile ("add %0, t1, zero" : "=r" (b)); // saving t1.
    asm volatile ("add %0, t2, zero" : "=r" (c)); // saving t2.

    asm volatile ("add t2, %1, zero" : "=r"(lock) : "r"(lock));
    asm volatile ("li t0, 1");

    asm volatile ("0:");
    asm volatile ("lw t1, (t2)");
    asm volatile ("bnez t1, 0b");
    asm volatile ("amoswap.w.aq t1, t0, (t2)");
    asm volatile ("bnez t1, 0b");

    asm volatile ("add t0, %1, zero" : "=r"(a) : "r"(a)); // restore t0.
    asm volatile ("add t1, %1, zero" : "=r"(b) : "r"(b)); // restore t1.
    asm volatile ("add t2, %1, zero" : "=r"(c) : "r"(c)); // restore t2.
}

void mutex_give(int *lock)
{
    int a, b;

    asm volatile ("add %0, t0, zero" : "=r" (a)); // saving t0.
    asm volatile ("add %0, t1, zero" : "=r" (b)); // saving t1.

    asm volatile ("add t1, %1, zero" : "=r"(lock) : "r"(lock));
    asm volatile ("amoswap.w.rl zero, zero, (t1)");

    asm volatile ("add t0, %1, zero" : "=r"(a) : "r"(a)); // restore t0.
    asm volatile ("add t1, %1, zero" : "=r"(b) : "r"(b)); // restore t1.
}

