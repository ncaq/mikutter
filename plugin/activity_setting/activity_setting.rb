# -*- coding: utf-8 -*-

require 'typed-array'

# アクティビティの設定の並び順
UserConfig[:activity_kind_order] = nil unless UserConfig[:activity_kind_order].is_a? Array
UserConfig[:activity_kind_order] ||= %w(
	retweet
	favorite
	follow
	list_member_added
	list_member_removed
	dm
	system
	ratelimit
	streaming_status
	error)

Plugin.create(:activity_setting) do

  def gen_listener_for_visible_check(uc, kind)
    UserConfig[uc] ||= []
    Plugin::Settings::Listener.new \
      get: ->(){ UserConfig[uc].include?(kind) rescue false },
      set: ->(value) do
        if value
          UserConfig[uc] += [kind]
        else
          UserConfig[uc] -= [kind] end end end

  def gen_listener_for_invisible_check(uc, kind)
    UserConfig[uc] ||= []
    Plugin::Settings::Listener.new \
      get: ->(){ (not UserConfig[uc].include?(kind)) rescue true },
      set: ->(value) do
        unless value
          UserConfig[uc] += [kind]
        else
          UserConfig[uc] -= [kind] end end end

  settings _("アクティビティ") do
    activity_kind = Plugin.filtering(:activity_kind, {})
    activity_kind_order = TypedArray(String).new
    if activity_kind
      activity_kind = activity_kind.last
      activity_kind.keys.each{ |kind|
        kind = kind.to_s
        i = where_should_insert_it(kind, activity_kind_order, UserConfig[:activity_kind_order])
        activity_kind_order.insert(i, kind) }
    else
      activity_kind_order = []
      activity_kind = {} end

    activity_kind_order.each do |kind|
      name = activity_kind[kind.to_sym]
      ml_param = {name: name}
      settings name do
        boolean(_('%{name}を表示する') % ml_param, gen_listener_for_invisible_check(:activity_mute_kind, kind)).tooltip(_('%{name}を、アクティビティタイムラインに表示します。チェックを外すと、%{name}の他の設定は無効になります。') % ml_param)
        boolean(_('自分に関係ない%{name}も表示する') % ml_param, gen_listener_for_invisible_check(:activity_mute_kind_related, kind)).tooltip(_('自分に関係ない%{name}もアクティビティタイムラインに表示されるようになります。チェックを外すと、自分に関係ない%{name}は表示されません。') % ml_param)
        boolean(_('タイムラインに表示'), gen_listener_for_visible_check(:activity_show_timeline, kind)).tooltip(_('%{name}が通知された時に、システムメッセージで%{name}を通知します') % ml_param)
        boolean(_('ステータスバーに表示'), gen_listener_for_visible_check(:activity_show_statusbar, kind)).tooltip(_('%{name}が通知された時に、ステータスバーにしばらく表示します') % ml_param)
      end
    end
  end

end
