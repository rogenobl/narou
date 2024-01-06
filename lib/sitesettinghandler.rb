# frozen_string_literal: true

require "weakref"
require_relative "worker"

#
# SiteSettingHandlerによって処理出来るように
# sitesetting.rb:99からのSiteSetting#multi_matchを書き換える
#
class SiteSetting
  def multi_match(source, *keys)
    match_data = nil
    keys.each do |key|
      setting_value = self[key] or next
      [*setting_value].each do |value|
        handle = SiteSettingHandler.handler(self, value)
        match_data = handle&.match(source) # ハンドルオブジェクトを得て、それにより処理する
        if match_data
          value = handle.value if handle.respond_to?(:value)
                                           # 通常はこれまで通りだが、valueを変更することも可能にする
          @match_values[key] = value       # yamlのキーでもmatch_valuesに設定しておくが、
          update_match_values(match_data)  # ←ここで同名のグループ名が定義されていたら上書きされるので注意
                                           # 例えば、title: <title>(?<title>.+?)</title> と定義されていた場合、
                                           # @match_values["title"] には (?<title>.+?) 部分の要素が反映される
          break
        end
      end
    end
    match_data
  end
end

class SiteSettingHandler
  HANDLER_DIR = "handler"
  HANDLER_EXT = ".rb"
  DEBUG_PRINT = false

  @@klasses = {}
  @@previousException = nil

  class << self
    # @type : ハンドラのタイプ名
    attr_reader :type
    #
    # ハンドラを読み込む
    #
    # require時に呼び出される
    # handler_dir (HANDLER_DIR) のファイルをrequireする
    # requireするファイルは基本的にはこのクラスを継承したハンドラクラスを定義し、
    # add_handlerを呼んで定義したクラスを登録する事で有効になる
    #
    def load_handler(handler_dir: HANDLER_DIR)
      Dir.glob(File.join(__dir__, handler_dir, "*"+HANDLER_EXT)) {|path|
        @@current_path = path
        begin
          require path
        rescue ScriptError, StandardError => e
          # 例外時、エラー内容は表示するが、処理は継続する
          warn e.full_message.lines[0..2]
        end
        @@current_path = nil
      }
    end
    #
    # ハンドラを登録する
    #
    # 継承したクラスで呼び出してハンドラを登録する
    # 通常、ファイル名からタイプ名を作るが、引数で直接指定も出来る
    # クラスを継承していない場合はクラスを指定して登録する
    #
    def add_handler(path_or_type: @@current_path, klass: self)
      @type = File.basename(path_or_type, HANDLER_EXT)
      @@klasses[@type] = klass
      puts "->#{__method__} #{@type} #{klass}" if DEBUG_PRINT
    end
    #
    # ハンドラの呼び出し
    #
    # 引数から対応するハンドラを呼び出しインスタンスを作る
    # 引数がこのクラスの派生オブジェクトならそのまま返す
    # それ以外でもメソッドmatchを持つならそのまま返す
    # それ以外なら正規表現であるので正規表現ハンドラにして返す
    #
    def handler(parent, value)
      case value
      when Array
        # key:
        #   type: value
        _make_handler(parent, *value)
      when Hash
        # key:
        #   - type: value
        _make_handler(parent, *value.flatten)
      when String
        # key:
        #   value
        /#{value}/m
      when self
        # 派生オブジェクトならそのまま返す
        value
      else
        if value.respond_to?(:match)
          # matchメソッドを持つオブジェクトならそのまま返す
          value
        else
          # その他であれば正規表現として生成
          _make_handler(parent, "regexp", value)
        end
      end
    rescue => e
      # 例外発生時、例外を記録するがnilを返して処理は続行する
      @@previousException = e
      nil
    end

    def _make_handler(parent, type, value)
      # typeが未登録の場合、例外が発生する
      klass = @@klasses.fetch(type)
      klass.make(value, WeakRef.new(parent))
    end

    # makeを再定義すれば別のインスタンスを返すことも可能
    alias make new

    # cattr_reader :previousException
    def previousException()
      @@previousException
    end
  end

  def initialize(value, parent)
    @value = value
    @parent = parent
  end
  #
  # ハンドラタイプ名
  # class_attribute :type, instance_writer: false
  #
  def type()
    self.class.type
  end
  #
  # 呼び出し元のオブジェクト
  #
  def parent()
    @parent&.weakref_alive? ? @parent : nil
  end
  #
  # デバッグ表示用
  #
  def to_s()
    "<#{self.class} @@type=#{self.type} @value=#{@value}>"
  end
  #
  # valueを定義すれば変更できる
  #
  #def value()
  #  @value
  #end
  #
  # sourceから値が得られるかチェックし、得られるなら値をセットする
  # 継承したクラスにて実装する
  #
  #def match(source)
  #  nil
  #end
  #
  # matchが返すmatch_dataのためのクラス
  #
  class PseudoMatchData < Hash
    attr_reader :post_match

    def initialize(post_match, hash)
      super()
      @post_match = post_match
      replace(hash)
    end

    def names()
      keys.map {|k| k.to_s}
    end
  end

  load_handler
end
