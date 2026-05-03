# frozen_string_literal: true

require "set"

module WestanRanking
  class RankingController < ::ApplicationController
    requires_plugin WestanRanking::PLUGIN_NAME

    before_action :ensure_logged_in, only: [:update_config, :search_users]
    before_action :ensure_staff, only: [:update_config, :search_users]

    STORE_KEY = "ranking_config"
    MONTHS = %w[jan. fev. mar. abr. mai. jun. jul. ago. set. out. nov. dez.].freeze
    DEFAULT_CONFIG = {
      "points_per_post" => 1,
      "points_per_topic" => 2,
      "vip_multiplier_cap" => 2,
      "period_start" => "",
      "period_end" => "",
      "excluded_user_ids" => []
    }.freeze

    def index
      config = ranking_config
      period_start, period_end = ranking_period(config)
      excluded_user_ids = normalized_excluded_user_ids(config)

      post_counts = post_counts_for(period_start, period_end, excluded_user_ids)
      topic_counts = topic_counts_for(period_start, period_end, excluded_user_ids)
      user_ids = (post_counts.keys + topic_counts.keys).uniq
      users = User.where(id: user_ids).to_a
      vip_user_ids = vip_user_ids_for(users)

      rows =
        users.map do |user|
          posts_count = post_counts[user.id] || 0
          topics_count = topic_counts[user.id] || 0
          base_points =
            posts_count * config["points_per_post"].to_i +
            topics_count * config["points_per_topic"].to_i
          vip_multiplier = vip_user_ids.include?(user.id) ? config["vip_multiplier_cap"].to_i : 1

          {
            id: user.id,
            username: user.username,
            display_name: user.name.presence || user.username,
            avatar_template: user.avatar_template,
            avatar_url: user.avatar_template&.gsub("{size}", "112"),
            posts_count: posts_count,
            topics_count: topics_count,
            is_vip: vip_multiplier > 1,
            vip_multiplier: vip_multiplier,
            base_points: base_points,
            total_points: base_points * vip_multiplier
          }
        end

      rows =
        rows
          .sort_by { |row| [-row[:total_points], -row[:topics_count], -row[:posts_count], row[:username].downcase] }
          .first(20)
          .each_with_index
          .map { |row, index| row.merge(position: index + 1) }

      render json: {
        rows: rows,
        config: config,
        period: {
          start: period_start.to_date.iso8601,
          end: period_end.to_date.iso8601,
          label: period_label(period_start, period_end)
        }
      }
    end

    def update_config
      config = ranking_config.merge(
        "points_per_post" => bounded_integer(params[:points_per_post], 0, 10, DEFAULT_CONFIG["points_per_post"]),
        "points_per_topic" => bounded_integer(params[:points_per_topic], 0, 10, DEFAULT_CONFIG["points_per_topic"]),
        "vip_multiplier_cap" => bounded_integer(params[:vip_multiplier_cap], 1, 10, DEFAULT_CONFIG["vip_multiplier_cap"]),
        "period_start" => params[:period_start].to_s,
        "period_end" => params[:period_end].to_s,
        "excluded_user_ids" => Array(params[:excluded_user_ids]).map(&:to_i).select(&:positive?).uniq
      )

      PluginStore.set(WestanRanking::PLUGIN_NAME, STORE_KEY, config)
      render json: { success: true, config: config }
    end

    def search_users
      term = params[:q].to_s.strip
      users = User
        .where("username_lower LIKE :term OR lower(name) LIKE :term", term: "%#{term.downcase}%")
        .order(:username_lower)
        .limit(12)

      render json: {
        users: users.map do |user|
          {
            id: user.id,
            username: user.username,
            display_name: user.name.presence || user.username,
            avatar_template: user.avatar_template,
            avatar_url: user.avatar_template&.gsub("{size}", "64")
          }
        end
      }
    end

    private

    def ensure_staff
      raise Discourse::InvalidAccess unless current_user&.staff?
    end

    def ranking_config
      stored = PluginStore.get(WestanRanking::PLUGIN_NAME, STORE_KEY)
      DEFAULT_CONFIG.merge(stored.is_a?(Hash) ? stored : {})
    end

    def ranking_period(config)
      if config["period_start"].present? && config["period_end"].present?
        period_start = Time.zone.parse(config["period_start"]).beginning_of_day
        period_end = Time.zone.parse(config["period_end"]).beginning_of_day
        return [period_start, period_end] if period_end > period_start
      end

      current_week_start = Time.zone.now.beginning_of_week(:monday)
      [current_week_start - 1.week, current_week_start]
    rescue ArgumentError, TypeError
      current_week_start = Time.zone.now.beginning_of_week(:monday)
      [current_week_start - 1.week, current_week_start]
    end

    def normalized_excluded_user_ids(config)
      Array(config["excluded_user_ids"]).map(&:to_i).select(&:positive?).uniq
    end

    def post_counts_for(period_start, period_end, excluded_user_ids)
      scope = Post
        .where(created_at: period_start...period_end)
        .where(post_type: Post.types[:regular])
        .where(deleted_at: nil)
        .where.not(user_id: nil)
      scope = scope.where.not(user_id: excluded_user_ids) if excluded_user_ids.present?
      scope.group(:user_id).count
    end

    def topic_counts_for(period_start, period_end, excluded_user_ids)
      scope = Topic
        .where(created_at: period_start...period_end)
        .where(deleted_at: nil)
        .where(archetype: Archetype.default)
        .where.not(user_id: nil)
      scope = scope.where.not(user_id: excluded_user_ids) if excluded_user_ids.present?
      scope.group(:user_id).count
    end

    def vip_user_ids_for(users)
      group_name = SiteSetting.westan_ranking_vip_group.to_s
      return Set.new if group_name.blank? || users.blank?

      group = Group.find_by(name: group_name)
      return Set.new unless group

      GroupUser.where(group_id: group.id, user_id: users.map(&:id)).pluck(:user_id).to_set
    end

    def bounded_integer(value, min, max, fallback)
      number = value.to_i
      number = fallback unless number.between?(min, max)
      number
    end

    def period_label(period_start, period_end)
      formatter = ->(date) { "#{date.day} de #{MONTHS[date.month - 1]}" }
      "#{formatter.call(period_start)} - #{formatter.call(period_end - 1.day)}"
    end
  end
end
