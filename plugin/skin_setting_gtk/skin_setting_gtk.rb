# -*- coding: utf-8 -*-

Plugin.create :skin do
  # プレビューアイコンのリスト
  def preview_icons(dir)
    famous_icons = [ "timeline.png", "reply.png", "activity.png", "directmessage.png" ]
    skin_icons = Dir.glob(File.join(dir, "*.png")).sort.map { |_| File.basename(_) }

    (famous_icons + skin_icons).uniq.select { |_| File.exist?(File.join(dir, _)) }[0, 12]
  end

  # スキンのプレビューを表示するウィジェットを生成する
  def preview_widget(info)
    fix = Gtk::Fixed.new
    frame = Gtk::Frame.new
    grid = Gtk::Grid.new

    preview_icons(info[:dir]).each do |path|
      image = Gtk::WebIcon.new(File.join(info[:dir], path), 32, 32)
      grid << image
    end

    fix.put(frame.add(grid), 17, 0)
  end

  # インストール済みスキンのリスト
  def skin_list()
    dirs = Dir.glob(File.join(Skin::SKIN_ROOT, "*")).select { |_|
      File.directory?(_)
    }.select { |_|
      Dir.glob(File.join(_, "*.png")).length != 0
    }.map { |_|
      _.gsub(/^#{Skin::SKIN_ROOT}\//, "")
    }

    dirs
  end

  # スキンの情報を得る
  def skin_infos()
    default_info = { :vanilla => { :face => _("（デフォルト）"), :dir => Skin::default_dir } }

    skin_infos_tmp = skin_list.inject({}) { |hash, _|
      hash[_] = { :face => _, :dir => File.join(Skin::SKIN_ROOT, _) }
      hash
    }

    default_info.merge(skin_infos_tmp)
  end

  # 設定
  settings(_("スキン")) do
    grid = Gtk::Grid.new
    current_radio = nil

    skin_infos.each { |slug, info|
      button = if current_radio
        Gtk::RadioButton.new(member: current_radio, label: info[:face])
      else
        Gtk::RadioButton.new(label: info[:face])
      end

      if slug == UserConfig[:skin_dir]
        button.active = true
      end

      button.ssc(:toggled) {
        if button.active?
          UserConfig[:skin_dir] = slug
        end
      }

      grid.attach_next_to button, nil, :bottom, 1, 1
      grid.attach_next_to preview_widget(info), button, :right, 1, 1

      current_radio = button
    }

    native grid
  end
end
