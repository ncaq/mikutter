# -*- coding: utf-8 -*-

require_relative 'error'
require_relative 'keep'
require_relative 'model/lost_world'

require 'digest/sha1'

Plugin.create(:world) do

  world_struct = Struct.new(:slug, :name, :proc)
  @world_slug_dict = {}         # world_slug(Symbol) => World URI(Diva::URI)

  defdsl :world_setting do |world_slug, world_name, &proc|
    filter_world_setting_list do |settings|
      [settings.merge(world_slug => world_struct.new(world_slug, world_name, proc))]
    end
  end

  # 登録済みアカウントを全て取得するのに使うフィルタ。
  # 登録されているWorld Modelをyielderに格納する。
  filter_worlds do |yielder|
    worlds.each do |world|
      yielder << world
    end
    [yielder]
  end

  # 新たなアカウント _new_ を追加する
  on_world_create do |new|
    register_world(new)
  end

  # アカウント _target_ が変更された時に呼ばれる
  on_world_modify do |target|
    modify_world(target)
  end

  # Worldのリストを、 _worlds_ の順番に並び替える。
  on_world_reorder do |new_order|
    store(:world_order, new_order.map(&method(:world_order_hash)))
    atomic do
      @worlds = worlds_sort(worlds)
      Plugin.call(:world_reordered, @worlds)
    end
  end

  # アカウント _target_ を削除する
  on_world_destroy do |target|
    destroy_world(target)
  end

  # すべてのWorld Modelを順番通りに含むArrayを返す。
  # 各要素は、アカウントの順番通りに格納されている。
  # 外部からこのメソッド相当のことをする場合は、 _worlds_ フィルタを利用すること。
  # ==== Return
  # [Array] アカウントModelを格納したArray
  def worlds
    if @worlds
      @worlds
    else
      atomic do
        @worlds ||= worlds_sort(load_world)
      end
    end
  end

  def world_order
    at(:world_order) || []
  end

  # 新たなアカウントを登録する。
  # ==== Args
  # [new] 追加するアカウント(Diva::Model)
  def register_world(new)
    return if target.is_a?(Plugin::World::LostWorld)
    Plugin::World::Keep.account_register new.slug, new.to_hash.merge(provider: new.class.slug)
    @worlds = nil
    Plugin.call(:world_after_created, new)
    Plugin.call(:service_registered, new) # 互換性のため
  rescue Plugin::World::AlreadyExistError
    description = {
      new_world: new.title,
      duplicated_world: @worlds.find{|w| w.slug == new.slug }&.title,
      world_slug: new.slug }
    activity :system, _('既に登録されているアカウントと重複しているため、登録に失敗しました。'),
             description: _('登録しようとしたアカウント「%{new_world}」は、既に登録されている「%{duplicated_world}」と同じ識別子「%{world_slug}」を持っているため、登録に失敗しました。') % description
  end

  def modify_world(target)
    return if target.is_a?(Plugin::World::LostWorld)
    if Plugin::World::Keep.accounts.has_key?(target.slug.to_sym)
      Plugin::World::Keep.account_modify target.slug, target.to_hash.merge(provider: target.class.slug)
      @worlds = nil
    end
  end

  def destroy_world(target)
    Plugin::World::Keep.account_destroy target.slug
    @worlds = nil
    Plugin.call(:service_destroyed, target) # 互換性のため
  end

  def load_world
    Plugin::World::Keep.accounts.map { |id, serialized|
      provider = Diva::Model(serialized[:provider])
      if provider
        provider.new(serialized)
      else
        Miquire::Plugin.load(serialized[:provider])
        provider = Diva::Model(serialized[:provider])
        if provider
          provider.new(serialized)
        else
          activity :system, _('アカウント「%{world}」のためのプラグインが読み込めなかったため、このアカウントは現在利用できません。') % {world: id},
                   description: _('アカウント「%{world}」に必要な%{plugin}プラグインが見つからなかったため、このアカウントは一時的に利用できません。%{plugin}プラグインを意図的に消したのであれば、このアカウントの登録を解除してください。') % {plugin: serialized[:provider], world: id}
          Plugin::World::LostWorld.new(serialized)
        end
      end
    }.compact.freeze.tap(&method(:check_world_uri))
  end

  def worlds_sort(world_list)
    world_list.sort_by.with_index do |a, index|
      [world_order.find_index(world_order_hash(a)) || Float::INFINITY, index]
    end
  end

  def check_world_uri(new_worlds)
    new_worlds.each do |w|
      if @world_slug_dict.key?(w.slug)
        if @world_slug_dict[w.slug] != w.uri
          warn "The URI of World `#{w.slug}' is not defined. You must define a consistent URI for World Model. see: https://dev.mikutter.hachune.net/issues/1231"
        end
      else
        @world_slug_dict[w.slug] = w.uri
      end
    end
  end

  def world_order_hash(world)
    Digest::SHA1.hexdigest("#{world.slug}mikutter")
  end
end
