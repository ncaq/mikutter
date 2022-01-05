# -*- coding:utf-8 -*-

Plugin.create :set_input do
  settings _('入力') do
    adjustment _('投稿をリトライする回数'), :message_retry_limit, 1, 99
    settings _('短縮URL') do
      boolean _('常にURLを短縮する'), :shrinkurl_always
    end
    settings _('フッタ') do
      input _('デフォルトで挿入するフッタ'), :footer
      boolean(_('リプライの場合はフッタを付与しない'), :footer_exclude_reply)
        .tooltip(_('リプライの時に[試験3日前]とか入ったらアレでしょう。そんなのともおさらばです。'))
    end
  end
end
