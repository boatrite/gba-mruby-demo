#include <mruby.h>
#include <mruby/irep.h>

extern const uint8_t ruby_main[];

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wunused-parameter"
mrb_value run_demo(mrb_state *mrb, mrb_value self) {
  // Write into the I/O registers, setting video display parameters.
  volatile unsigned char *ioram = (unsigned char *)0x04000000;
  ioram[0] = 0x03; // Use video mode 3 (in BG2, a 16bpp bitmap in VRAM)
  ioram[1] = 0x04; // Enable BG2 (BG0 = 1, BG1 = 2, BG2 = 4, ...)

  // Write pixel colours into VRAM
  volatile unsigned short *vram = (unsigned short *)0x06000000;
  vram[80 * 240 + 115] = 0x001F; // X = 115, Y = 80, C = 000000000011111 = R
  vram[60 * 240 + 120] = 0x03E0; // X = 120, Y = 60, C = 000001111100000 = G
  vram[80 * 240 + 145] = 0x7C00; // X = 125, Y = 80, C = 111110000000000 = B

  return mrb_nil_value();
}
#pragma GCC diagnostic pop

mrb_state *new_ruby_vm() {
  // Start Ruby VM
  mrb_state *mrb = mrb_open();

  // Define Ruby extensions backed by C
  struct RClass *GBA_class = mrb_define_class(mrb, "GBA", mrb->object_class);

  mrb_define_class_method(mrb, GBA_class, "run_demo", run_demo, MRB_ARGS_NONE());

  // Load in our mruby bytecode
  mrb_load_irep(mrb, ruby_main);

  return mrb;
}

int main(void) {
  mrb_state *mrb = new_ruby_vm();
  mrb_close(mrb);

  // Wait forever
  while (1) {
  };

  return 0;
}
