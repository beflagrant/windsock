# frozen_string_literal: true

module Windsock
  class Railtie < ::Rails::Railtie
    config.windsock = ActiveSupport::OrderedOptions.new

    initializer "windsock.path" do |app|
      Windsock.path ||= app.config.windsock.path || app.root.join("app/assets/tailwind/application.css")
    end

    initializer "windsock.helper" do
      ActiveSupport.on_load(:action_view) { include Windsock::Helper }
    end

    # Re-parse when any CSS under the stylesheet's directory changes.
    initializer "windsock.reloader" do |app|
      config = app.config
      reloading = config.respond_to?(:reloading_enabled?) ? config.reloading_enabled? : !config.cache_classes
      next unless reloading

      dir = File.dirname(Windsock.path.to_s)
      next unless File.directory?(dir)

      watcher = app.config.file_watcher.new([], { dir => ["css"] }) { Windsock.reset! }
      app.reloaders << watcher
      app.reloader.to_run { watcher.execute_if_updated }
    end
  end
end
