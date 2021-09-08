# -*- coding: utf-8 -*-

require_relative 'conditions'

Plugin.create :command do

  on_gui_child_activated do |i_window, i_pane|
    if i_window.is_a?(Plugin::GUI::Window) and i_pane.is_a?(Plugin::GUI::Pane)
      last_active_pane[i_window.slug] = i_pane end end

  command(:copy_selected_region,
          name: _('コピー'),
          condition: ->opt{ opt.messages.size == 1 && opt.widget&.selected_text(opt.messages.first)},
          visible: true,
          icon: Skin[:copy],
          role: :timeline) do |opt|
    Plugin.call(:clipboard_write, opt.widget.selected_text(opt.messages.first))
  end

  command(:copy_description,
          name: _('本文をコピー'),
          condition: ->opt{ opt.messages.size == 1 },
          visible: true,
          icon: Skin[:copy_all],
          role: :timeline) do |opt|
    Plugin.call(:clipboard_write, opt.messages.first.description)
  end

  command(:reply,
          name: _('返信'),
          condition: ->opt{ !opt.messages.empty? && compose?(opt.world, to: opt.messages) },
          visible: true,
          icon: Skin[:reply],
          role: :timeline) do |opt|
    messages = opt.messages
    opt.widget.create_postbox(to: messages,
                              header: messages.select{|x|x.respond_to?(:idname)}.map{|x| "@#{x.idname}"}.uniq.join(' ') + ' ',
                              use_blind_footer: !UserConfig[:footer_exclude_reply]) end

  command(:reply_all,
          name: _('全員に返信'),
          condition: ->opt{ !opt.messages.empty? && compose?(opt.world, to: opt.messages) },
          visible: true,
          icon: Skin[:reply],
          role: :timeline) do |opt|
    messages = opt.messages.map{ |m| m.ancestors.to_a }.flatten
    opt.widget.create_postbox(to: messages,
                              header: messages.map(&:user).uniq.reject(&:me?).select{|x|x.respond_to?(:idname)}.map{|x| "@#{x.idname}"}.join(' ') + ' ',
                              use_blind_footer: !UserConfig[:footer_exclude_reply]) end

  command(:legacy_retweet,
          name: _('引用'),
          condition: ->opt{ opt.messages.size == 1 && compose?(opt.world, to: opt.messages) },
          visible: true,
          role: :timeline) do |opt|
    m = opt.messages.first
    opt.widget.create_postbox(to: [m],
                              footer: " RT @#{m.idname}: #{m.description}",
                              to_display_only: !UserConfig[:legacy_retweet_act_as_reply],
                              use_blind_footer: !UserConfig[:footer_exclude_retweet]) end

  command(:retweet,
          name: _('リツイート'),
          condition: ->opt{ opt.messages.any?{|m| share?(opt.world, m) && !shared?(opt.world, m) } },
          visible: true,
          icon: Skin[:retweet],
          role: :timeline) do |opt|
    target = opt.messages.select{|m| share?(m, opt.world) }.reject{|m| shared?(m, opt.world) }.map(&:introducer)
    target.deach { |m|
      if m.from_me?([opt.world])
        +dialog(_('リツイート')) {
          label _('過去の栄光にすがりますか？')
          link m
        }.next {
          share(m, opt.world)
        }
      else
        share(m, opt.world)
      end
    }
  end

  command(:delete_retweet,
          name: _('リツイートをキャンセル'),
          condition: ->opt{ !opt.messages.empty? && opt.messages.all?{|m| destroy_share?(opt.world, m) } },
          visible: true,
          icon: Skin[:retweet_cancel],
          role: :timeline) do |opt|
    Delayer::Deferred.when(
      opt.messages.map{|m| destroy_share(opt.world, m) }
    ).terminate(_('リツイートをキャンセルしている途中でエラーが発生しました'))
  end

  command(:favorite,
          name: _('ふぁぼふぁぼする'),
          condition: ->opt{ opt.messages.any?{|m| favorite?(opt.world, m) && !favorited?(opt.world, m) } },
          visible: true,
          icon: Skin[:unfav],
          role: :timeline) do |opt|
    Delayer::Deferred.when(
      opt.messages.select{|m|
        favorite?(opt.world, m) && !favorited?(opt.world, m)
      }.map{|m|
        favorite(opt.world, m)
      }
    ).terminate(_('ふぁぼふぁぼしている途中でエラーが発生しました'))
  end

  command(:delete_favorite,
          name: _('あんふぁぼ'),
          condition: ->opt{ !opt.messages.empty? && opt.messages.all?{|m| unfavorite?(opt.world, m) } },
          visible: true,
          icon: Skin[:fav],
          role: :timeline) do |opt|
    Delayer::Deferred.when(
      opt.messages.map{|m| unfavorite(opt.world, m) }
    ).terminate(_('あんふぁぼしている途中でエラーが発生しました'))
  end

  command(:delete,
          name: _('削除'),
          condition: ->opt{ !opt.messages.empty? && opt.messages.all?{|m| destroy?(opt.world, m) } },
          visible: true,
          icon: Skin[:close],
          role: :timeline) do |opt|
    opt.messages.deach { |m|
      +dialog(_('削除')) {
        label _('失った信頼はもう戻ってきませんが、本当にこのつぶやきを削除しますか？')
        link m
      }.next {
        destroy(opt.world, m)
      }
    }
  end

  command(:aboutuser,
          name: ->(opt) {
            if opt
              (_("%{title}について") % { title: opt.messages&.first&.user&.title }).gsub(/_/, '__')
            else
              _('投稿者について')
            end
          },
          condition: ->(opt) { !opt.messages.empty? && compose?(opt.world, to: opt.messages) },
          visible: true,
          icon: ->(opt) { opt && opt.messages.first.user.icon },
          role: :timeline) do |opt|
    Plugin.call(:open, opt.messages.first.user) end

  command(:select_prev,
          name: _('一つ上のメッセージを選択'),
          condition: :itself.to_proc,
          visible: false,
          role: :timeline) do |opt|
    Plugin.call(:gui_timeline_move_cursor_to, opt.widget, :prev) end

  command(:select_next,
          name: _('一つ下のメッセージを選択'),
          condition: :itself.to_proc,
          visible: false,
          role: :timeline) do |opt|
    Plugin.call(:gui_timeline_move_cursor_to, opt.widget, :next) end

  command(:post_it,
          name: _('投稿する'),
          condition: ->opt{ opt.widget&.editable? },
          visible: true,
          icon: Skin[:post],
          role: :postbox) do |opt|
    opt.widget.post_it!(world: opt.world)
  end

  command(:google_search,
          name: _('ggrks'),
          condition: ->opt{ opt.messages.size == 1 && opt.widget.selected_text(opt.messages.first) },
          visible: true,
          icon: "https://www.google.co.jp/images/google_favicon_128.png",
          role: :timeline) do |opt|
    Plugin.call(:open, "http://www.google.co.jp/search?q=" + URI.escape(opt.widget.selected_text(opt.messages.first)).to_s) end

  command(:open_in_browser,
          name: _('ブラウザで開く'),
          condition: ->opt{ opt.messages.size == 1 && opt.messages.first.perma_link },
          visible: true,
          role: :timeline) do |opt|
    Plugin.call(:open, Diva::Model(:web)&.new(perma_link: opt.messages.first.perma_link)) end

  command(:open_link,
          name: _('リンクを開く'),
          condition: ->opt{
            opt.messages.size == 1 &&
              opt.messages[0].entity.any? { |u| %i[urls media].include?(u[:slug]) }
          },
          visible: true,
          role: :timeline) do |opt|
    opt.messages[0].entity.each do |u|
      url =
        case u[:slug]
        when :urls
          u[:expanded_url] || u[:url]
        when :media
          u[:media_url]
        end
      Plugin.call(:open, url) if url
    end
  end

  command(:copy_link,
          name: _('リンクをコピー'),
          condition: ->opt{
            opt.messages.size == 1 &&
              opt.messages[0].entity.any? {|u| u[:slug] == :urls }
          },
          visible: true,
          role: :timeline) do |opt|
    opt.messages[0].entity.each do |u|
      Plugin.call(:clipboard_write, u[:url]) if u[:slug] == :urls
    end
  end

  command(:new_pane,
          name: _('新規ペインに移動'),
          condition: ->opt{
            pane = opt.widget.parent
            pane.is_a?(Plugin::GUI::Pane) && pane.children.size != 1
          },
          visible: true,
          role: :tab) do |opt|
    tab = opt.widget.is_a?(Plugin::GUI::Tab) ? opt.widget : opt.widget.ancestor_of(Plugin::GUI::Tab)
    window = tab.ancestor_of(Plugin::GUI::Window)
    if window
      pane = Plugin::GUI::Pane.instance
      pane << tab
      window << pane
    else
      error "window not found."
    end
  end

  command(:close,
          name: _('タブを閉じる'),
          condition: ->opt{
            opt.widget.deletable
          },
          visible: true,
          icon: Skin[:close],
          role: :tab) do |opt|
    opt.widget.destroy
  end

  command(:focus_right_tab,
          name: _('次のタブを選択'),
          condition: :itself.to_proc,
          visible: false,
          role: :tab) do |opt|
    focus_move_widget(opt.widget, 1)
  end

  command(:focus_left_tab,
          name: _('前のタブを選択'),
          condition: :itself.to_proc,
          visible: false,
          role: :tab) do |opt|
    focus_move_widget(opt.widget, -1)
  end

  command(:focus_right_pane,
          name: _('右のペインを選択'),
          condition: :itself.to_proc,
          visible: false,
          role: :pane) do |opt|
    focus_move_widget(opt.widget, -1)
  end

  command(:focus_left_pane,
          name: _('左のペインを選択'),
          condition: :itself.to_proc,
          visible: false,
          role: :pane) do |opt|
    focus_move_widget(opt.widget, 1)
  end

  command(:focus_to_postbox,
          name: _('投稿ボックスにフォーカス'),
          condition: ->opt{
            if opt.widget.respond_to? :active_chain
              not opt.widget.active_chain.last.is_a? Plugin::GUI::Postbox
            else
              opt.widget.is_a? Plugin::GUI::Postbox end
          },
          visible: false,
          role: :window) do |opt|
    focus_move_to_nearest_postbox(opt.widget.active_chain.last)
  end

  command(:focus_to_tab,
          name: _('タブにフォーカス'),
          condition: :itself.to_proc,
          visible: false,
          role: :postbox) do |opt|
    focus_move_to_latest_widget(opt.widget)
  end

  command(:timeline_scroll_to_top,
          name: _('タイムラインの一番上にジャーンプ！'),
          condition: :itself.to_proc,
          visible: false,
          role: :timeline) do |opt|
    Plugin.call :gui_timeline_scroll, opt.widget, :top
  end

  command(:scroll_up,
          name: _('上にスクロール'),
          condition: :itself.to_proc,
          visible: false,
          role: :timeline) do |opt|
    Plugin.call :gui_timeline_scroll, opt.widget, :up
  end

  command(:scroll_down,
          name: _('下にスクロール'),
          condition: :itself.to_proc,
          visible: false,
          role: :timeline) do |opt|
    Plugin.call :gui_timeline_scroll, opt.widget, :down
  end

  # フォーカスを _widget_ から _distance_ に移動する
  # ==== Args
  # [widget] 起点となるウィジェット
  # [distance] 移動距離
  def focus_move_widget(widget, distance)
    type_strict widget => Plugin::GUI::HierarchyParent
    type_strict widget => Plugin::GUI::HierarchyChild
    children = widget.parent.children.select{ |w| w.is_a? widget.class }
    index = children.index(widget)
    term = children[(index + distance) % children.size]
    term = term.active_chain.last if term.respond_to? :active_chain
    term.active! if term
    src_tl = widget.active_chain.last
    if widget.is_a?(Plugin::GUI::Pane) and src_tl.is_a?(Plugin::GUI::Timeline) and term.is_a?(Plugin::GUI::Timeline)
      slide_timeline_focus(src_tl, term) end end

  # タイムライン _src_ で選択されているディスプレイ上のy座標が同じ _dest_ のツイートに
  # フォーカスを移動する
  # ==== Args
  # [src] フォーカスを取得するタイムライン
  # [dest] フォーカスを設定するタイムライン
  def slide_timeline_focus(src, dest)
    type_strict src => Plugin::GUI::Timeline, dest => Plugin::GUI::Timeline
    y = Plugin.filtering(:gui_timeline_cursor_position, src, nil).last
    if y
      Plugin.call(:gui_timeline_move_cursor_to, dest, y) end end

  # 一番近い postbox にフォーカスを与える
  # ==== Args
  # [widget] 基準となるウィジェット
  def focus_move_to_nearest_postbox(widget)
    if widget.is_a? Plugin::GUI::HierarchyParent
      postbox = widget.children.find{ |w| w.is_a? Plugin::GUI::Postbox }
      if postbox
        return postbox.active! end end
    if widget.is_a? Plugin::GUI::HierarchyChild
      focus_move_to_nearest_postbox(widget.parent) end end

  # 最後にアクティブだったペインにフォーカスを与える。
  # 親タイムラインがあれば、それにフォーカスを与える。
  # ==== Args
  # [postbox] 基準となるウィジェット
  def focus_move_to_latest_widget(postbox)
    if postbox.parent.is_a? Plugin::GUI::Window
      pane = last_active_pane[postbox.parent.slug]
      pane.active! if pane
    else
      postbox.parent.active! end end

  def last_active_pane
    @last_active_pane ||= {} end

end
