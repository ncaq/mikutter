# frozen_string_literal: true

UserConfig[:profile_icon_size] ||= 48
UserConfig[:profile_icon_margin] ||= 4

Plugin.create :modelviewer do
  defdsl :defmodelviewer do |model_class, &block|
    model_class = Diva::Model(model_class) unless model_class.is_a?(Class)
    filter_modelviewer_models do |models|
      models << model_class.spec
      [models]
    end
    intent(model_class,
           label: _('%{model}の詳細') % {model: model_class.spec&.name || model_class.name},
           slug: :"modelviewer:#{model_class.slug}"
          ) do |token|
      model = token.model
      tab_slug = :"modelviewer:#{model_class.slug}:#{model.uri.hash}"
      cluster_slug = :"modelviewer-cluster:#{model_class.slug}:#{model.uri.hash}"
      if Plugin::GUI::Tab.exist?(tab_slug)
        Plugin::GUI::Tab.instance(tab_slug).active!
      else
        tab(tab_slug, _('%{title}について') % {title: model.title}) do
          set_icon model.icon if model.respond_to?(:icon)
          set_deletable true
          temporary_tab true
          shrink
          nativewidget Plugin[:modelviewer].header(token, &block)
          expand
          Plugin[:modelviewer].cluster_initialize(model, cluster(cluster_slug))
          active!
        end
      end
    end
  end

  # プロフィールタブを定義する
  # ==== Args
  # [slug] タブスラッグ
  # [title] タブのタイトル
  defdsl :deffragment do |model_class, slug, title=slug.to_s, &block|
    model_class = Diva::Model(model_class) unless model_class.is_a?(Class)
    add_event_filter(:"modelviewer_#{model_class.slug}_fragments") do |tabs, model|
      i_fragment = Plugin::GUI::Fragment.instance(:"modelviewer-fragment:#{slug}:#{model.uri}", title)
      i_fragment.instance_eval_with_delegate(self, model, &block)
      tabs << i_fragment
      [tabs, model]
    end
  end

  on_gui_child_reordered do |i_cluster, i_fragment, order|
    kind, = i_fragment.slug.to_s.split(':', 2)
    if kind == 'modelviewer-fragment'
      _, cluster_kind, = i_cluster.slug.to_s.split(':', 3)
      store("order-#{cluster_kind}", i_cluster.children.map { |f| f.slug.to_s.split(':', 3)[1] })
    end
  end

  def cluster_initialize(model, i_cluster)
    _, cluster_kind, = i_cluster.slug.to_s.split(':', 3)
    order = at("order-#{cluster_kind}", [])
    fragments = Plugin.collect(:"modelviewer_#{model.class.slug}_fragments", Pluggaloid::COLLECT, model).sort_by { |i_fragment|
      _, fragment_kind, = i_fragment.slug.to_s.split(':', 3)
      order.index(fragment_kind) || Float::INFINITY
    }.to_a
    fragments.each(&i_cluster.method(:add_child))
    fragments.first&.active!
  end

  def header(intent_token, &column_generator)
    model = intent_token.model

    icon = model_icon model
    icon.margin = UserConfig[:profile_icon_margin]
    icon.valign = :start

    title = title_widget model
    title.hexpand = true

    table = header_table(model, column_generator.(model))
    table.hexpand = true

    grid = Gtk::Grid.new
    grid.margin_top = grid.margin_bottom = 4
    grid.attach_next_to icon, nil, :left, 1, 2
    grid.attach_next_to title, icon, :right, 1, 1
    grid.attach_next_to table, title, :bottom, 1, 1
    grid
  end

  def model_icon(model)
    return ::Gtk::EventBox.new unless model.respond_to?(:icon)
    icon = ::Gtk::EventBox.new.add(::Gtk::WebIcon.new(model.icon, UserConfig[:profile_icon_size], UserConfig[:profile_icon_size]).tooltip(_('アイコンを開く')))
    icon.ssc(:button_press_event) do |this, event|
      Plugin.call(:open, model.icon)
      true
    end
    icon.ssc(:realize) do |this|
      this.window.set_cursor(Gdk::Cursor.new(:hand2))
      false
    end
    icon
  end

  # modelのtitleを表示する
  # ==== Args
  # [model] 表示するmodel
  # [intent_token] ユーザを開くときに利用するIntent
  # ==== Return
  # ユーザの名前の部分のGtkコンテナ
  def title_widget(model)
    score = [
      Plugin::Score::HyperLinkNote.new(
        description: model.title,
        uri: model.uri
      )
    ]
    ::Gtk::IntelligentTextview.new(score)
  end

  # modelのtitleを表示する
  # ==== Args
  # [model] 表示するmodel
  # [intent_token] ユーザを開くときに利用するIntent
  # ==== Return
  # ユーザの名前の部分のGtkコンテナ
  def cell_widget(model_or_str)
    case model_or_str
    when Diva::Model
      ::Gtk::IntelligentTextview.new(
        Plugin[:modelviewer].score_of(model_or_str),
      )
    else
      Gtk::Label.new model_or_str.to_s
    end
  end

  def header_table(model, rows)
    grid = Gtk::Grid.new
    grid.row_spacing = 4
    grid.column_spacing = 16

    rows.each do |header, content|
      label_header = Gtk::Label.new header
      label_header.halign = :end

      widget_content = cell_widget content
      widget_content.halign = :start

      grid.attach_next_to label_header, nil, :bottom, 1, 1
      grid.attach_next_to widget_content, label_header, :right, 1, 1
    end
    grid
  end
end
