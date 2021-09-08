# -*- coding: utf-8 -*-
# 通知管理プラグイン

require_relative 'model/activity'

Plugin.create(:activity) do

  # 新しいアクティビティの種類を定義する。設定に表示されるようになる
  # ==== Args
  # [kind] 種類
  # [name] 表示する名前
  defdsl :defactivity do |kind, name|
    kind, name = kind.to_sym, name.to_s
    filter_activity_kind do |data|
      data[kind] = name
      [data] end end

  on_favorite do |service, user, message|
    activity(:favorite, "#{message.user[:idname]}: #{message.to_s}",
             description:(_("@%{user} がふぁぼふぁぼしました") % {user: user[:idname]} + "\n" +
                          "@#{message.user[:idname]}: #{message.to_s}"),
             icon: user.icon,
             related: message.user.me? || user.me?,
             service: service,
             children: [user, message, message.user])
  end

  on_unfavorite do |service, user, message|
    activity(:unfavorite, "#{message.user[:idname]}: #{message.to_s}",
             description:(_("@%{user} があんふぁぼしました") % {user: user[:idname]} + "\n" +
                          "@#{message.user[:idname]}: #{message.to_s}"),
             icon: user.icon,
             related: message.user.me? || user.me?,
             service: service,
             children: [user, message, message.user])
  end

  on_retweet do |retweets|
    retweets.each { |retweet|
      retweet.retweet_source_d.next{ |source|
        activity(:retweet, retweet.to_s,
                 description:(_("@%{user} がリツイートしました") % {user: retweet.user[:idname]} + "\n" +
                              "@#{source.user[:idname]}: #{source.to_s}"),
                 icon: retweet.user.icon,
                 date: retweet[:created],
                 related: (retweet.user.me? || source && source.user.me?),
                 service: Service.primary,
                 children: [retweet.user, source, source.user]) }.terminate(_ 'リツイートソースが取得できませんでした') }
  end

  defactivity :retweet, _("リツイート")
  defactivity :favorite, _("ふぁぼ")
  defactivity :follow, _("フォロー")
  defactivity :list_member_added, _("リストに追加")
  defactivity :list_member_removed, _("リストから削除")
  defactivity :dm, _("ダイレクトメッセージ")
  defactivity :system, _("システムメッセージ")
  defactivity :error, _("エラー")

end
