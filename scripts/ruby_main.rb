class GBA
  module Input
    A = 1
    B = 2
    SELECT = 4
    START = 8
    RIGHT = 16
    LEFT = 32
    UP = 64
    DOWN = 128
    R = 256
    L = 512
  end

  def self.set_ioram(index, value)
    set_char_memory(GBA::MEM_IO, index, value)
  end

  def self.set_vram(index, value)
    set_short_memory(GBA::MEM_VRAM, index, value)
  end

  def self.input_pressed?(input)
    key_states & input != 0
  end
end

class RubyMain
  def self.call
    unless GBA::NDEBUG
      debug
      return
    end

    # --- "Pong" ---

    # Write the color palette for our sprites into the first palette of
    # 16 colors in color palette memory (this palette has index 0)
    GBA.set_object_palette_memory(1, 0x1F, 0x1F, 0x1F) # White
    GBA.set_object_palette_memory(2, 0x1F, 0x00, 0x1F) # Magenta

    # Write the tiles for our sprites into the fourth tile block in VRAM.
    # Four tiles for an 8x32 paddle sprite, and one tile for an 8x8 ball
    # sprite. Using 4bpp, 0x1111 is four pixels of colour index 1, and
    # 0x2222 is four pixels of colour index 2.
    GBA.set_tile_memory(1, 4, 0x1111) # paddle
    GBA.set_tile_memory(5, 1, 0x2222) # ball

    # 4bpp tiles, TALL shape
    # 8x32 size when using the TALL shape
    # Start at the first tile in tile
    # block four, use color palette zero
    GBA.set_obj_attrs(0, 0x8000, 0x4000, 1) # 0 = paddle index

    # 4bpp tiles, SQUARE shape
    # 8x8 size when using the SQUARE shape
    # Start at the fifth tile in tile block four,
    # use color palette zero
    GBA.set_obj_attrs(1, 0, 0, 5) # 1 = ball index

    player_width = 8
    player_height = 32
    ball_width = 8
    ball_height = 8
    player_velocity = 2
    ball_velocity_x = 2
    ball_velocity_y = 1
    player_x = 5
    player_y = 96
    ball_x = 22
    ball_y = 96

    GBA.set_object_position(0, player_x, player_y) # 0 = paddle index
    GBA.set_object_position(1, ball_x, ball_y) # 1 = ball index

    # Set the display parameters to enable objects, and use a 1D
    # object->tile mapping
    GBA.reg_display = 0x1000 | 0x0040

    loop do
      while GBA.reg_display_vcount >= 160
        # Wait till VDraw
      end
      while GBA.reg_display_vcount < 160
        # Wait till VBlank
      end

      player_max_clamp_y = GBA::SCREEN_HEIGHT - player_height

      if GBA.input_pressed? GBA::Input::UP
        player_y = (player_y - player_velocity).clamp(0, player_max_clamp_y)
      end

      if GBA.input_pressed? GBA::Input::DOWN
        player_y = (player_y + player_velocity).clamp(0, player_max_clamp_y)
      end

      if GBA.input_pressed?(GBA::Input::UP) || GBA.input_pressed?(GBA::Input::DOWN)
        GBA.set_object_position(0, player_x, player_y)
      end

      ball_max_clamp_x = GBA::SCREEN_WIDTH - ball_width
      ball_max_clamp_y = GBA::SCREEN_HEIGHT - ball_height
      if (ball_x >= player_x && ball_x <= player_x + player_width) &&
          (ball_y >= player_y && ball_y <= player_y + player_height)
        ball_x = player_x + player_width
        ball_velocity_x = -ball_velocity_x
      else
        if ball_x == 0 || ball_x == ball_max_clamp_x
          ball_velocity_x = -ball_velocity_x
        end
        if ball_y == 0 || ball_y == ball_max_clamp_y
          ball_velocity_y = -ball_velocity_y
        end
      end

      ball_x = (ball_x + ball_velocity_x).clamp(0, ball_max_clamp_x)
      ball_y = (ball_y + ball_velocity_y).clamp(0, ball_max_clamp_y)
      GBA.set_object_position(1, ball_x, ball_y)
    end
  end

  def self.debug
    GBA.enable_console

    puts "Ruby loaded. Execution starting."

    puts "NDEBUG: #{GBA::NDEBUG}"
    puts "MEM_IO: #{GBA::MEM_IO.to_s(16)}"
    puts "MEM_VRAM: #{GBA::MEM_VRAM.to_s(16)}"

    loop do
      # puts "reg_display_vcount: #{GBA.reg_display_vcount}"

      puts "A Held" if GBA.input_pressed?(GBA::Input::A)
      puts "B Held" if GBA.input_pressed?(GBA::Input::B)
      puts "Select Held" if GBA.input_pressed?(GBA::Input::SELECT)
      puts "Start Held" if GBA.input_pressed?(GBA::Input::START)
      puts "Right Held" if GBA.input_pressed?(GBA::Input::RIGHT)
      puts "Left Held" if GBA.input_pressed?(GBA::Input::LEFT)
      puts "Up Held" if GBA.input_pressed?(GBA::Input::UP)
      puts "Down Held" if GBA.input_pressed?(GBA::Input::DOWN)
      puts "R Held" if GBA.input_pressed?(GBA::Input::R)
      puts "L Held" if GBA.input_pressed?(GBA::Input::L)
    end
  end
end
