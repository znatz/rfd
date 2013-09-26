require 'fileutils'

module Rfd
  VERSION = Gem.loaded_specs['rfd'].version.to_s

  module MODE
    COMMAND = :command
    MIEL = :miel
  end

  module Commands
    def d
      FileUtils.mv current_item.path, File.expand_path('~/.Trash/')
      ls
    end

    def k
      @row -= 1
      @row = @items.size - 1 if @row <= 0
      move_cursor @row
    end

    def j
      @row += 1
      @row = 0 if @row >= @items.size
      move_cursor @row
    end

    def q
      raise StopIteration
    end

    def v
      switch_mode MODE::MIEL
      @viewer = ViewerWindow.new
      @viewer.draw current_item.read
    end

    def enter
      if current_item.directory?
        cd current_item
        ls
      else
        v
      end
    end
  end

  class Window
    def draw(contents)
      @win.setpos 0, 0
      @win.addstr contents
      @win.refresh
    end
  end

  # bordered Window
  class SubWindow < Window
    def initialize(*)
      border_window = Curses.stdscr.subwin @win.maxy + 2, @win.maxx + 2, @win.begy - 1, @win.begx - 1
      border_window.box ?|, ?-
    end
  end

  class BaseWindow < Window
    attr_reader :main
    attr_writer :mode

    def initialize(dir = '.')
      init_colors

      @win = Curses.stdscr
      @win.box ?|, ?-
      @header = HeaderWindow.new
      @main = MainWindow.new base: self, dir: dir
      @main.move_cursor 0
      @mode = MODE::COMMAND
    end

    def init_colors
      Curses.init_pair Curses::COLOR_WHITE, Curses::COLOR_WHITE, Curses::COLOR_BLACK
      Curses.init_pair Curses::COLOR_CYAN, Curses::COLOR_CYAN, Curses::COLOR_BLACK
    end
    def command_mode?
      @mode == MODE::COMMAND
    end

    def miel_mode?
      @mode == MODE::MIEL
    end

    def move_cursor(row)
      @win.setpos row, 1
    end

    def debug(str)
      @header.draw str
    end

    def enter
      @main.enter
    end

    def bs
      if miel_mode?
        @mode = MODE::COMMAND
        @main.close_viewer
      end
    end

    def q
      @main.q
    end
  end

  class HeaderWindow < SubWindow
    def initialize
      @win = Curses.stdscr.subwin 6, Curses.stdscr.maxx - 2, 1, 1
      super
    end
  end

  class MainWindow < SubWindow
    include Rfd::Commands

    def initialize(base: nil, dir: nil)
      @base = base
      @win = Curses.stdscr.subwin Curses.stdscr.maxy - 9, Curses.stdscr.maxx - 2, 8, 1
      @row = 0
      super

      cd dir
      ls
      @win.refresh
    end

    def current_item
      @items[@row]
    end

    def move_cursor(row)
      @base.move_cursor @win.begy + row
    end

    def switch_mode(mode)
      @base.mode = mode
    end

    def close_viewer
      @viewer.close
      ls
    end

    def cd(dir)
      @dir = File.expand_path(dir.is_a?(Rfd::Item) ? dir.path : dir)
    end

    def ls
      @win.clear
      @items = Dir.foreach(@dir).map {|fn| Item.new dir: @dir, name: fn}
      @items.each do |item|
        @win.attron Curses.color_pair(item.color) do
          @win.addstr "#{item.to_s}\n"
        end
      end
      @win.refresh
      move_cursor 0
    end
  end

  class ViewerWindow < SubWindow
    def initialize
      @win = Curses.stdscr.subwin Curses.stdscr.maxy - 9, Curses.stdscr.maxx - 2, 8, 1
    end

    def close
      @win.close
    end
  end

  class Item
    def initialize(dir: nil, name: nil)
      @dir, @name = dir, name
    end

    def path
      @path ||= File.join @dir, @name
    end

    def stat
      @stat ||= File.stat path
    end

    def color
      if directory?
        Curses::COLOR_CYAN
      else
        Curses::COLOR_WHITE
      end
    end

    def size
      if directory?
        '<DIR>'
      else
        stat.size
      end
    end

    def directory?
      stat.directory?
    end

    def read
      File.read path
    end

    def to_s
      "#{@name.ljust(43)}#{size}"
    end
  end
end
