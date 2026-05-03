# frozen_string_literal: true

module WestanRanking
  class Engine < ::Rails::Engine
    engine_name WestanRanking::PLUGIN_NAME
    isolate_namespace WestanRanking
    config.autoload_paths << File.join(config.root, "lib")
  end
end
