#include <x265.h>

// workaround for x265 "glue" macro swift will expand
x265_encoder* x265_encoder_open_swift(x265_param *p) {
    return x265_encoder_open(p);
}
