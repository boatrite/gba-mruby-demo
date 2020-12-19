#ifndef NDEBUG
#define NDEBUG true
#endif

#include <gba_console.h>
#include <gba_input.h>
#include <gba_interrupt.h>
#include <gba_systemcalls.h>
#include <gba_video.h>

#include <mruby.h>
#include <mruby/irep.h>

extern const uint8_t ruby_main[];

#define SCREEN_WIDTH 240
#define SCREEN_HEIGHT 160

#define MEM_IO      0x04000000
#define MEM_PALETTE 0x05000000
#define MEM_VRAM    0x06000000
#define MEM_OAM     0x07000000

#define REG_DISPLAY        (*((volatile uint32_t *)(MEM_IO)))
#define REG_DISPLAY_VCOUNT (*((volatile uint32_t *)(MEM_IO + 0x0006)))
#define REG_KEY_INPUT      (*((volatile uint32_t *)(MEM_IO + 0x0130)))

#define KEY_UP   0x0040
#define KEY_DOWN 0x0080
#define KEY_ANY  0x03FF

#define OBJECT_ATTR0_Y_MASK 0x0FF
#define OBJECT_ATTR1_X_MASK 0x1FF

typedef uint16_t rgb15;
typedef struct obj_attrs {
  uint16_t attr0;
  uint16_t attr1;
  uint16_t attr2;
  uint16_t pad;
} __attribute__((packed, aligned(4))) obj_attrs;
typedef uint32_t tile_4bpp[8];
typedef tile_4bpp tile_block[512];

#define OAM_MEM ((volatile obj_attrs *)MEM_OAM)
#define TILE_MEM ((volatile tile_block *)MEM_VRAM)
#define OBJECT_PALETTE_MEM ((volatile rgb15 *)(MEM_PALETTE + 0x200))

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

// Form a 16-bit BGR GBA colour from three component values
static inline rgb15 RGB15(int r, int g, int b)
{
  return r | (g << 5) | (b << 10);
}

// Set the position of an object to specified x and y coordinates
static inline void set_object_position(volatile obj_attrs *object, int x, int y)
{
  object->attr0 = (object->attr0 & ~OBJECT_ATTR0_Y_MASK) |
    (y & OBJECT_ATTR0_Y_MASK);
  object->attr1 = (object->attr1 & ~OBJECT_ATTR1_X_MASK) |
    (x & OBJECT_ATTR1_X_MASK);
}

mrb_value setTileMemory(mrb_state *mrb, mrb_value self) {
  int index;
  int count;
  int value;
  mrb_get_args(mrb, "iii", &index, &count, &value);

  /* printf("index: %d\n", index); */
  /* printf("count: %d\n", count); */
  /* printf("value: %x\n", value); */

  volatile uint16_t *sprite_tile_mem = (uint16_t *)TILE_MEM[4][index];

  for (int i = 0; i < count * (sizeof(tile_4bpp) / 2); ++i) {
    sprite_tile_mem[i] = value; // e.g. 0x1111 == 0b_0001_0001_0001_0001
  }

  return mrb_nil_value();
}

mrb_value setObjectPaletteMemory(mrb_state *mrb, mrb_value self) {
  int index;
  int red;
  int green;
  int blue;
  mrb_get_args(mrb, "iiii", &index, &red, &green, &blue);

  OBJECT_PALETTE_MEM[index] = RGB15(red, green, blue);

  return mrb_nil_value();
}

mrb_value setObjAttrs(mrb_state *mrb, mrb_value self) {
  int index;
  int attr0;
  int attr1;
  int attr2;
  mrb_get_args(mrb, "iiii", &index, &attr0, &attr1, &attr2);

  volatile obj_attrs *attrs = &OAM_MEM[index];
  attrs->attr0 = attr0;
  attrs->attr1 = attr1;
  attrs->attr2 = attr2;

  return mrb_nil_value();
}

mrb_value setObjectPosition(mrb_state *mrb, mrb_value self) {
  int index;
  int x;
  int y;
  mrb_get_args(mrb, "iii", &index, &x, &y);

  volatile obj_attrs *attrs = &OAM_MEM[index];
  set_object_position(attrs, x, y);

  return mrb_nil_value();
}

mrb_value setRegDisplay(mrb_state *mrb, mrb_value self) {
  int value;
  mrb_get_args(mrb, "i", &value);

  REG_DISPLAY = value;

  return mrb_nil_value();
}

mrb_value setShortMemory(mrb_state *mrb, mrb_value self) {
  volatile unsigned short *address;
  int index;
  int value;
  mrb_get_args(mrb, "iii", &address, &index, &value);
  address[index] = value;
  return mrb_nil_value();
}

mrb_value setCharMemory(mrb_state *mrb, mrb_value self) {
  volatile unsigned char *address;
  int index;
  int value;
  mrb_get_args(mrb, "iii", &address, &index, &value);
  address[index] = value;
  return mrb_nil_value();
}

mrb_value enable_console(mrb_state *mrb, mrb_value self) {
  irqInit();
  irqEnable(IRQ_VBLANK);
  // Eventually I bet I can lookup what consoleDemoInit does, and find a way to
  // reverse it, and eventually flip back and forth between them maybe
  consoleDemoInit();
}

mrb_value key_states(mrb_state *mrb, mrb_value self) {
  return mrb_fixnum_value(~REG_KEY_INPUT & KEY_ANY);
}

mrb_value reg_display_vcount(mrb_state *mrb, mrb_value self) {
  return mrb_fixnum_value(REG_DISPLAY_VCOUNT);
}

mrb_state *new_ruby_vm() {
  // Start Ruby VM
  mrb_state *mrb = mrb_open();

  // Define Ruby extensions backed by C
  struct RClass *GBA_class = mrb_define_class(mrb, "GBA", mrb->object_class);

  mrb_define_class_method(mrb, GBA_class, "run_demo", run_demo, MRB_ARGS_NONE());

  mrb_define_class_method(mrb, GBA_class, "set_short_memory", setShortMemory, MRB_ARGS_REQ(3));
  mrb_define_class_method(mrb, GBA_class, "set_char_memory", setCharMemory, MRB_ARGS_REQ(3));
  mrb_define_class_method(mrb, GBA_class, "set_tile_memory", setTileMemory, MRB_ARGS_REQ(3));
  mrb_define_class_method(mrb, GBA_class, "set_object_palette_memory", setObjectPaletteMemory, MRB_ARGS_REQ(4));
  mrb_define_class_method(mrb, GBA_class, "set_obj_attrs", setObjAttrs, MRB_ARGS_REQ(4));
  mrb_define_class_method(mrb, GBA_class, "set_object_position", setObjectPosition, MRB_ARGS_REQ(3));
  mrb_define_class_method(mrb, GBA_class, "reg_display=", setRegDisplay, MRB_ARGS_REQ(1));
  mrb_define_class_method(mrb, GBA_class, "enable_console", enable_console, MRB_ARGS_NONE());
  mrb_define_class_method(mrb, GBA_class, "key_states", key_states, MRB_ARGS_NONE());
  mrb_define_class_method(mrb, GBA_class, "reg_display_vcount", reg_display_vcount, MRB_ARGS_NONE());

  mrb_define_const(mrb, GBA_class, "NDEBUG", mrb_bool_value(NDEBUG));
  mrb_define_const(mrb, GBA_class, "SCREEN_HEIGHT", mrb_fixnum_value(SCREEN_HEIGHT));
  mrb_define_const(mrb, GBA_class, "SCREEN_WIDTH", mrb_fixnum_value(SCREEN_WIDTH));
  mrb_define_const(mrb, GBA_class, "MEM_IO", mrb_fixnum_value(MEM_IO));
  mrb_define_const(mrb, GBA_class, "MEM_VRAM", mrb_fixnum_value(MEM_VRAM));

  // Load in our mruby bytecode
  mrb_load_irep(mrb, ruby_main);

  return mrb;
}

int main(void) {
  mrb_state *mrb = new_ruby_vm();
  mrb_load_string(mrb, "RubyMain.call");
  mrb_close(mrb);
  return 0;
}
