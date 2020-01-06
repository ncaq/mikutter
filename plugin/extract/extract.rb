# -*- coding: utf-8 -*-

require_relative 'extract_settings'
require_relative 'model/setting'

module Plugin::Extract
  class ConditionNotFoundError < RuntimeError; end

  ExtensibleCondition = Struct.new(:slug, :name, :operator, :args) do
    def initialize(*_args, &block)
      super
      @block = block end

    def to_proc
      @block end

    def call(*_args, **_named, &block)
      @block.(*_args, **_named, &block) end end

  class ExtensibleSexpCondition < ExtensibleCondition
    attr_reader :sexp

    def initialize(*args)
      @sexp = args.pop
      super(*args) end
  end

  ExtensibleOperator = Struct.new(:slug, :name, :args) do
    def initialize(*_args, &block)
      super
      @block = block end

    def to_proc
      @block end

    def call(*_args, **_named, &block)
      @block.(*_args, **_named, &block) end end

  Order = Struct.new(:slug, :name, :ordering)

  class Calc
    def self.inherited(child)
      child.class_eval do
        operators = Plugin.filtering(:extract_operator, Set.new).first
        operators.each { |operator|
          define_method(operator.slug) do |other|
            @condition.(other, message: @message, operator: operator.slug, &operator)
          end
        }
      end
    end

    def initialize(message, condition)
      type_strict condition => Plugin::Extract::ExtensibleCondition
      @message, @condition = message, condition
    end

    def call(*args)
      @condition.(*args, message: @message)
    end
  end
end

Plugin.create :extract do

  # 抽出タブオブジェクト。各キーは抽出タブslugで、値は以下のようなオブジェクト
  # name :: タブの名前
  # sexp :: 条件式（S式）
  # source :: どこのツイートを見るか（イベント名、配列で複数）
  # slug :: タイムラインとタブのスラッグ
  def extract_tabs
    @extract_tabs ||= {} end

  command(:extract_edit,
          name: _('抽出条件を編集'),
          condition: lambda{ |opt|
            extract_tabs.values.any? { |es| es.slug == opt.widget.slug }
          },
          visible: true,
          role: :tab) do |opt|
    extract = extract_tabs.values.find { |es| es.slug == opt.widget.slug }
    Plugin.call(:extract_open_edit_dialog, extract.slug) if extract
  end

  defdsl :defextractcondition do |slug, name: raise, operator: true, args: 0, sexp: nil, &block|
    if sexp
      filter_extract_condition do |conditions|
        conditions << Plugin::Extract::ExtensibleSexpCondition.new(slug, name, operator, args, sexp).freeze
        [conditions] end
    else
      filter_extract_condition do |conditions|
        conditions << Plugin::Extract::ExtensibleCondition.new(slug, name, operator, args, &block).freeze
        [conditions] end end end

  defdsl :defextractoperator do |slug, name: raise, args: 1, &block|
    filter_extract_operator do |operators|
      operators << Plugin::Extract::ExtensibleOperator.new(slug, name, args, &block).freeze
      [operators] end end

  defdsl :defextractorder do |slug, name:, &block|
    slug = slug.to_sym
    name = name.to_s.freeze
    filter_extract_order do |orders|
      orders << Plugin::Extract::Order.new(slug, name, block)
      [orders]
    end
  end

  defextractoperator(:==, name: _('＝'), args: 1, &:==)
  defextractoperator(:!=, name: _('≠'), args: 1, &:!=)
  defextractoperator(:match_regexp, name: _('正規表現'), args: 1, &:match_regexp)
  defextractoperator(:include?, name: _('含む'), args: 1, &:include?)

  defextractcondition(:user, name: _('ユーザ名'), operator: true, args: 1, sexp: MIKU.parse("`(,compare (idname (user message)) ,(car args))"))

  defextractcondition(:body, name: _('本文'), operator: true, args: 1, sexp: MIKU.parse("`(,compare (description message) ,(car args))"))

  defextractcondition(:source, name: _('投稿したクライアントアプリケーション名'), operator: true, args: 1, sexp: MIKU.parse("`(,compare (fetch message 'source) ,(car args))"))

  defextractcondition(:receiver_idnames, name: _('宛先ユーザ名のいずれか一つ以上'), operator: true, args: 1) do |arg, message: raise, operator: raise, &compare|
    message.receive_user_idnames.any? do |sn|
      compare.(sn, arg)
    end
  end

  defextractorder(:created, name: _('投稿時刻')) do |model|
    model.created.to_i
  end

  defextractorder(:modified, name: _('投稿時刻 (ふぁぼやリツイートでageる)')) do |model|
    model.modified.to_i
  end

  on_extract_tab_create do |setting|
    if setting.is_a?(Hash)
      setting = Plugin::Extract::Setting.new(setting)
    end
    extract_tabs[setting.slug] = setting
    tab(setting.slug, setting.name) do
      set_icon setting.icon.to_s if setting.icon?
      timeline setting.slug do
        oo = setting.find_ordering_obj
        order(&setting.find_ordering_obj.ordering) if oo
      end
    end
    modify_extract_tabs end

  on_extract_tab_update do |setting|
    extract_tabs[setting.slug] = setting
    tab(setting.slug).set_icon setting.icon.to_s if setting.icon?
    oo = setting.find_ordering_obj
    timeline(setting.slug).order(&oo.ordering) if oo
    modify_extract_tabs end

  on_extract_tab_delete do |slug|
    if extract_tabs.has_key? slug
      deleted_tab = extract_tabs[slug]
      tab(deleted_tab.slug).destroy
      extract_tabs.delete(slug)
      modify_extract_tabs end end

  on_extract_receive_message do |source, messages|
    append_message source, messages
  end

  filter_extract_tabs_get do |tabs|
    [tabs + extract_tabs.values]
  end

  filter_active_datasources do |ds|
    [ds + active_datasources]
  end

  # 抽出タブの現在の内容を保存する
  def modify_extract_tabs
    UserConfig[:extract_tabs] = extract_tabs.values.map(&:export_to_userconfig)
    self end

  # 使用されているデータソースのSetを返す
  def active_datasources
    @active_datasources ||=
      extract_tabs.values.map{|tab|
      tab.sources
    }.inject(Set.new, &:merge).freeze
  end

  def compile(tab_slug, code)
    atomic do
      @compiled ||= {}
      @compiled[tab_slug] ||=
        if code.empty?
          ret_nth
        else
          begin
            before = Set.new
            extract_condition ||= Hash[Plugin.filtering(:extract_condition, []).first.map{ |condition| [condition.slug, condition] }]
            evaluated = MIKU::Primitive.new(:to_ruby_ne).call(MIKU::SymbolTable.new, metamorphose(code: code, assign: before, extract_condition: extract_condition))
            code_string = "lambda{ |message|\n" + before.to_a.join("\n") + "\n  " + evaluated + "\n}"
            instance_eval(code_string)
          rescue Plugin::Extract::ConditionNotFoundError => exception
            Plugin.call(:modify_activity,
                        plugin: self,
                        kind: 'error'.freeze,
                        title: _("抽出タブ条件エラー"),
                        date: Time.new,
                        description: _("抽出タブ「%{tab_name}」で使われている条件が見つかりませんでした:\n%{error_string}") % {tab_name: extract_tabs[tab_slug].name, error_string: exception.to_s})
            warn exception
            ret_nth end end end end

  # 条件をこう、くいっと変形させてな
  def metamorphose(code: raise, assign: Set.new, extract_condition: nil)
    extract_condition ||= Hash[Plugin.filtering(:extract_condition, []).first.map{ |condition| [condition.slug, condition] }]
    case code
    when MIKU::Atom
      return code
    when MIKU::List
      return true if code.empty?
      condition = if code.size <= 2
                    extract_condition[code.car]
                  else
                    extract_condition[code.cdr.car] end
      case condition
      when Plugin::Extract::ExtensibleSexpCondition
        metamorphose_sexp(code: code, condition: condition)
      when Plugin::Extract::ExtensibleCondition
        assign << "#{condition.slug} = Class.new(Plugin::Extract::Calc).new(message, extract_condition[:#{condition.slug}])"
        if condition.operator
          code
        else
          # MIKU::Cons.new(:call, MIKU::Cons.new(condition.slug, nil))
          [:call, condition.slug]
        end
      else
        if code.cdr.car.is_a? Symbol and not %i[and or not].include?(code.car)
          raise Plugin::Extract::ConditionNotFoundError, _('抽出条件 `%{condition}\' が見つかりませんでした') % {condition: code.cdr.car} end
        code.map{|node| metamorphose(code: node,
                                     assign: assign,
                                     extract_condition: extract_condition) } end end end

  def metamorphose_sexp(code: raise, condition: raise)
    miku_context = MIKU::SymbolTable.new
    miku_context[:compare] = MIKU::Cons.new(code.car, nil)
    miku_context[:args] = MIKU::Cons.new(code.cdr.cdr, nil)
    begin
      miku(condition.sexp, miku_context)
    rescue => exception
      error "error occurred in code #{MIKU.unparse(condition.sexp)}"
      error miku_context
      raise exception end end

  def destroy_compile_cache
    atomic do
      @compiled = {} end end

  def append_message(source, messages)
    type_strict source => Symbol, messages => Enumerable
    tabs = extract_tabs.values.select{ |r| r.sources && r.using?(source) }
    return if tabs.empty?
    converted_messages = messages.map{ |message| message.retweet_source ? message.retweet_source : message }
    tabs.each{ |record|
        filtered_messages = timeline(record.slug).not_in_message(converted_messages.select(&compile(record.slug, record.sexp)))
        timeline(record.slug) << filtered_messages
        notificate_messages = filtered_messages.lazy.select{|message| message[:created] > defined_time}
        if record.popup?
          notificate_messages.deach do |message|
            Plugin.call(:popup_notify, message.user, message.description) end end
        if record.sound.is_a?(String) and notificate_messages.first and FileTest.exist?(record.sound)
          Plugin.call(:play_sound, record.sound) end
    } end

  (UserConfig[:extract_tabs] or []).each do |record|
    Plugin.call(:extract_tab_create, Plugin::Extract::Setting.new(record))
  end

  on_userconfig_modify do |key, val|
    next if key != :extract_tabs
    destroy_compile_cache
    @active_datasources = nil
  end
end
