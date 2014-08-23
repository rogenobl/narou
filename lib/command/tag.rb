# -*- coding: utf-8 -*-
#
# Copyright 2013 whiteleaf. All rights reserved.
#

require_relative "../database"
require_relative "../downloader"
require_relative "../inventory"

module Command
  class Tag < CommandBase
    COLORS = %w(green yellow blue magenta cyan red white)

    def self.oneline_help
      "各小説にタグを設定及び閲覧が出来ます"
    end

    def initialize
      super("<option> <tagname> <target> [<target2> ...]\n" \
            "<tagname> [<tagname2> ...]")
      @opt.separator <<-EOS

  ・小説にタグを設定します。設定個数の上限はありません
  ・タグ名にはスペース以外の文字が使えます(大文字小文字区別)
  ・タグには自動で色がつきます。自分で指定する場合は--colorを指定して下さい

  Examples:
    narou tag --add fav 0 2     # ID:0と1の小説にfavタグを設定(追加)
    narou t -a fav 0 2          # もしくはこの様に書けます
    narou t -a "fav later" 0 2  # 一度に複数のタグを指定出来ます
    narou t -a fav -c red 0     # favというタグを赤色で設定する
    narou tag --delete fav 2    # ID:2の小説のfavタグを外す
    narou t -d fav 2

    narou tag fav               # favタグの付いている小説の一覧を表示
    narou tag fav later         # fav,laterタグ両方付いている小説を表示
    narou tag                   # 何も指定しない場合、存在するタグ一覧を表示

  Options:
      EOS
      @opt.on("-a", "--add TAGS", String, "タグを追加する") { |tags|
        @options["mode"] = :add
        @options["tags"] = tags.split
      }
      @opt.on("-d", "--delete TAGS", String, "タグを外す") { |tags|
        @options["mode"] = :delete
        @options["tags"] = tags.split
      }
      @opt.on("-c", "--color COL", String,
              "タグの色を自分で指定する\n" \
              "#{' '*25}COL=#{get_color_list}".termcolor) { |color|
        color.downcase!
        unless COLORS.include?(color)
          error "#{color}という色は存在しません。色指定は無視されます"
          color = nil
        end
        @options["color"] = color
      }
      @opt.on("--clear", "指定した小説のタグをすべて外す") {
        @options["mode"] = :clear
      }
    end

    def get_color_list
      COLORS.map { |color|
        "<bold><#{color}>#{color}</#{color}></bold>"
      }.join(",")
    end

    def execute(argv)
      super
      @options["mode"] ||= :list
      if argv.empty?
        if @options["mode"] == :list
          display_taglist
          return
        end
        error "対象の小説を指定して下さい"
        exit 1
      else
        if @options["mode"] == :list
          search_novel_by_tag(argv)
        else
          edit_tags(argv)
        end
      end
    end

    def display_taglist
      database = Database.instance
      tags_list = {}
      database.each do |_, data|
        tags = data["tags"] || []
        tags.each do |tag|
          if tags_list[tag]
            tags_list[tag] += 1
          else
            tags_list[tag] = 1
          end
        end
      end
      puts "タグ一覧"
      puts tags_list.map { |tag, count|
        color = Tag.get_color(tag)
        "<bold><#{color}>#{tag}(#{count})</#{color}></bold>"
      }.join(" ").termcolor
    end

    def search_novel_by_tag(argv)
      List.execute!(["--tag", argv.join(" ")])
    end

    def edit_tags(argv)
      database = Database.instance
      argv.each do |target|
        data = Downloader.get_data_by_target(target)
        unless data
          error "#{target} は存在しません"
          next
        end
        tags = data["tags"] || []
        title = data["title"]
        case @options["mode"]
        when :add
          tags |= @options["tags"]
          puts "#{title} にタグを設定しました"
        when :delete
          tags -= @options["tags"]
          puts "#{title} からタグを外しました"
        when :clear
          tags.clear
          puts "#{title} のタグをすべて外しました"
        end
        if @options["color"] && @options["tags"]
          @options["tags"].each do |tag|
            set_color(tag, @options["color"])
          end
        end
        if tags.count > 0
          print "現在のタグは "
          print tags.map { |tagname|
            color = Tag.get_color(tagname)
            "<bold><#{color}>#{TermColor.escape(tagname)}</#{color}></bold>"
          }.join(" ").termcolor
          puts " です"
        end
        database[data["id"]]["tags"] = tags
      end
      database.save_database
    end

    def self.get_color(tagname)
      @@tag_colors ||= Inventory.load("tag_colors", :local)
      color = @@tag_colors[tagname]
      return color if color
      last_color = @@tag_colors.values.last || COLORS.last
      index = (COLORS.index(last_color) + 1) % COLORS.count
      color = COLORS[index]
      @@tag_colors[tagname] = color
      @@tag_colors.save
      color
    end

    def set_color(tagname, color)
      @@tag_colors ||= Inventory.load("tag_colors", :local)
      @@tag_colors[tagname] = color
      @@tag_colors.save
    end
  end
end
