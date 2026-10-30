/* Passive dylib load test. No ObjC classes, initializers, hooks or network calls. */
__attribute__((visibility("default"), used))
unsigned int zero_v28_probe_marker(void) { return 0x2828u; }
