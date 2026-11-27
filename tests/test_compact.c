#include <assert.h>
#include <stdio.h>
#include "../Sources/NB27CompactState.h"
static unsigned long checks;
#define CHECK(x) do { assert(x); ++checks; } while (0)
int main(void) {
    NB27CompactState s = {0};
    CHECK(!NB27CompactStateBegin(&s, true));
    CHECK(!NB27CompactStateFinish(&s, 0));
    NB27CompactStateEnable(&s, true);
    uintptr_t a = NB27CompactStateBegin(&s, true);
    uintptr_t b = NB27CompactStateBegin(&s, true);
    CHECK(a && b > a);
    CHECK(!NB27CompactStateFinish(&s, a) && !s.retained);
    CHECK(!NB27CompactStateAbort(&s, a) && s.pending == b);
    CHECK(NB27CompactStateFinish(&s, b) && s.retained);
    CHECK(!NB27CompactStateAbort(&s, a) && s.retained);
    CHECK(!NB27CompactStateAbort(&s, b) && s.retained);
    CHECK(!NB27CompactStateFinish(&s, b));
    a = NB27CompactStateBegin(&s, true);
    CHECK(s.retained); /* Entrance/reference changes do not touch this model. */
    CHECK(NB27CompactStateAbort(&s, a) && s.retained);
    a = NB27CompactStateBegin(&s, true);
    CHECK(!NB27CompactStateBegin(&s, false) && s.retained && !s.pending);
    CHECK(!NB27CompactStateFinish(&s, a) && s.retained);
    a = NB27CompactStateBegin(&s, true);
    NB27CompactStateEnable(&s, false); /* Only the user preference clears retention. */
    CHECK(!s.retained && !s.pending);
    NB27CompactStateEnable(&s, true);
    b = NB27CompactStateBegin(&s, true);
    CHECK(b > a && !NB27CompactStateFinish(&s, a));
    CHECK(NB27CompactStateFinish(&s, b));
    NB27CompactStateEnable(&s, true);
    CHECK(s.retained); /* Repeated enabled/temporary system hiding is not reset. */
    for (unsigned i = 0; i < 100000; ++i) {
        a = NB27CompactStateBegin(&s, true);
        b = NB27CompactStateBegin(&s, true);
        CHECK(b > a && !NB27CompactStateAbort(&s, a));
        CHECK(!NB27CompactStateFinish(&s, a) && s.pending == b);
        CHECK(NB27CompactStateFinish(&s, b) && s.retained);
        CHECK(!NB27CompactStateAbort(&s, a) && s.retained);
    }
    s.generation = UINTPTR_MAX - 1;
    a = NB27CompactStateBegin(&s, true);
    CHECK(a == UINTPTR_MAX && NB27CompactStateFinish(&s, a));
    CHECK(!NB27CompactStateBegin(&s, true) && !s.pending && s.retained);
    NB27CompactStateEnable(&s, false);
    NB27CompactStateEnable(&s, true);
    CHECK(!NB27CompactStateBegin(&s, true) && !s.retained);
    CHECK(!NB27CompactStateFinish(&s, a));
    printf("PASS: %lu compact generation/retention assertions; no UIKit runtime claim\n", checks);
    return 0;
}
