#pragma once
#include <stdbool.h>
#include <stdint.h>

/* Zero-initialized; disabling never resets generation (no ABA ticket reuse). */
typedef struct {
    uintptr_t generation, pending, retainedTicket;
    bool enabled, retained;
} NB27CompactState;
static inline void NB27CompactStateEnable(NB27CompactState *s, bool enabled) {
    s->enabled = enabled;
    if (!enabled) { s->pending = 0; s->retained = false; s->retainedTicket = 0; }
}
static inline uintptr_t NB27CompactStateBegin(NB27CompactState *s, bool supported) {
    s->pending = 0; /* Even an unsupported newer exit supersedes the old one. */
    if (!s->enabled || !supported || s->generation == UINTPTR_MAX) return 0;
    s->pending = ++s->generation;
    return s->pending;
}
static inline bool NB27CompactStateFinish(NB27CompactState *s, uintptr_t ticket) {
    if (!s->enabled || !ticket || ticket != s->pending) return false;
    s->pending = 0; s->retained = true; s->retainedTicket = ticket;
    return true;
}
static inline bool NB27CompactStateExpire(NB27CompactState *s, uintptr_t ticket) {
    if (!s->enabled || !s->retained || !ticket || ticket != s->retainedTicket) return false;
    s->retained = false; s->retainedTicket = 0;
    return true;
}
static inline bool NB27CompactStateAbort(NB27CompactState *s, uintptr_t ticket) {
    if (!s->enabled || !ticket || ticket != s->pending) return false;
    s->pending = 0; /* Never erase an earlier normally retained indicator. */
    return true;
}
