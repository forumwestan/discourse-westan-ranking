import Component from "@glimmer/component";
import { action } from "@ember/object";
import { on } from "@ember/modifier";
import { service } from "@ember/service";
import { tracked } from "@glimmer/tracking";
import dIcon from "discourse/helpers/d-icon";
import { ajax } from "discourse/lib/ajax";

export default class WestanRankingBoard extends Component {
  @service currentUser;

  @tracked rankings =
    this.args.model.rankings ||
    {
      weekly: {
        rows: this.args.model.rows || [],
        period: this.args.model.period || {},
        current_user: null,
      },
      monthly: { rows: [], period: {}, current_user: null },
    };
  @tracked config = this.args.model.config || {};
  @tracked activePeriod = "weekly";
  @tracked showInfo = false;
  @tracked showSettings = false;
  @tracked draft = { ...this.config };
  @tracked userSearch = "";
  @tracked userResults = [];
  @tracked isSaving = false;

  get canManage() {
    return this.currentUser?.admin || this.currentUser?.moderator;
  }

  get activeRanking() {
    return this.rankings[this.activePeriod] || { rows: [], period: {} };
  }

  get activeRows() {
    return this.activeRanking.rows || [];
  }

  get hasRows() {
    return this.activeRows.length > 0;
  }

  get podiumRows() {
    const rows = this.activeRows;
    return [rows[1], rows[0], rows[2]]
      .filter(Boolean)
      .map((row) => ({
        ...row,
        is_winner: row.position === 1,
        podium_class: `westan-ranking-podium__member is-position-${row.position}`,
      }));
  }

  get listRows() {
    return this.activeRows.slice(3);
  }

  get hasListRows() {
    return this.listRows.length > 0;
  }

  get currentUserRank() {
    return this.activeRanking.current_user;
  }

  get title() {
    return this.activePeriod === "weekly" ? "Ranking Semanal" : "Ranking Mensal";
  }

  get periodLabel() {
    return this.activeRanking.period?.label || "Período atual";
  }

  get updateLabel() {
    return this.activePeriod === "weekly"
      ? "Atualiza às segundas-feiras"
      : "Acompanha o mês atual";
  }

  get weeklyTabClass() {
    return this.activePeriod === "weekly" ? "is-active" : "";
  }

  get isWeekly() {
    return this.activePeriod === "weekly";
  }

  get monthlyTabClass() {
    return this.activePeriod === "monthly" ? "is-active" : "";
  }

  get isMonthly() {
    return this.activePeriod === "monthly";
  }

  get excludedUserIds() {
    return this.draft.excluded_user_ids || [];
  }

  get userResultRows() {
    return this.userResults.map((user) => ({
      ...user,
      is_excluded: this.excludedUserIds.includes(user.id),
    }));
  }

  get pointsPerPost() {
    return this.config.points_per_post || 1;
  }

  get pointsPerTopic() {
    return this.config.points_per_topic || 2;
  }

  get vipMultiplierCap() {
    return this.config.vip_multiplier_cap || 2;
  }

  @action
  selectPeriod(event) {
    this.activePeriod = event.currentTarget.dataset.period;
  }

  @action
  openSettings() {
    this.draft = {
      ...this.config,
      excluded_user_ids: [...(this.config.excluded_user_ids || [])],
    };
    this.userSearch = "";
    this.userResults = [];
    this.showSettings = true;
  }

  @action
  closeSettings() {
    this.showSettings = false;
  }

  @action
  openInfo() {
    this.showInfo = true;
  }

  @action
  closeInfo() {
    this.showInfo = false;
  }

  @action
  updateDraft(event) {
    const field = event.currentTarget.dataset.field;
    this.draft = { ...this.draft, [field]: event.target.value };
  }

  @action
  updateDraftNumber(event) {
    const field = event.currentTarget.dataset.field;
    this.draft = { ...this.draft, [field]: Number(event.target.value) };
  }

  @action
  resetPeriod() {
    this.draft = { ...this.draft, period_start: "", period_end: "" };
  }

  @action
  excludeUser(event) {
    const userId = Number(event.currentTarget.dataset.userId);
    if (this.excludedUserIds.includes(userId)) {
      return;
    }
    this.draft = {
      ...this.draft,
      excluded_user_ids: [...this.excludedUserIds, userId],
    };
  }

  @action
  includeUser(event) {
    const userId = Number(event.currentTarget.dataset.userId);
    this.draft = {
      ...this.draft,
      excluded_user_ids: this.excludedUserIds.filter((id) => id !== userId),
    };
  }

  @action
  async searchUsers(event) {
    this.userSearch = event.target.value;
    if (this.userSearch.trim().length < 2) {
      this.userResults = [];
      return;
    }

    const response = await ajax("/westan/ranking/users", {
      data: { q: this.userSearch.trim() },
    });
    this.userResults = response.users || [];
  }

  @action
  async saveSettings() {
    this.isSaving = true;
    await ajax("/westan/ranking/config", {
      type: "PATCH",
      data: this.draft,
    });
    const refreshed = await ajax("/westan/ranking");
    this.rankings = refreshed.rankings || this.rankings;
    this.config = refreshed.config || {};
    this.isSaving = false;
    this.showSettings = false;
  }

  <template>
    <header class="westan-ranking-hero">
      <div class="westan-ranking-hero__topline">
        <div>
          <p>Ranking Westan</p>
          <h1>{{this.title}}</h1>
        </div>
        <div class="westan-ranking-hero__actions">
          {{#if this.canManage}}
            <button type="button" class="westan-ranking-icon-button" aria-label="Configurações do ranking" {{on "click" this.openSettings}}>
              {{dIcon "gear"}}
            </button>
          {{/if}}
          <button type="button" class="westan-ranking-icon-button westan-ranking-icon-button--accent" aria-label="Entenda como funciona o ranking" {{on "click" this.openInfo}}>
            {{dIcon "circle-info"}}
          </button>
        </div>
      </div>

      <div class="westan-ranking-tabs" role="tablist" aria-label="Período do ranking">
        <button
          type="button"
          class={{this.weeklyTabClass}}
          data-period="weekly"
          role="tab"
          aria-selected={{this.isWeekly}}
          {{on "click" this.selectPeriod}}
        >
          Semanal
        </button>
        <button
          type="button"
          class={{this.monthlyTabClass}}
          data-period="monthly"
          role="tab"
          aria-selected={{this.isMonthly}}
          {{on "click" this.selectPeriod}}
        >
          Mensal
        </button>
      </div>

    </header>

    {{#if this.hasRows}}
      <section class="westan-ranking-podium" aria-label="Top 3 do ranking">
        {{#each this.podiumRows as |row|}}
          <article class={{row.podium_class}}>
            <div class="westan-ranking-podium__avatar">
              {{#if row.is_winner}}
                <span class="westan-ranking-podium__crown" aria-hidden="true">
                  <svg viewBox="0 0 256 256" focusable="false">
                    <path d="M246.46 73.17a16 16 0 0 0-17.74-2.26l-46.9 23.38l-40-66.49a16.11 16.11 0 0 0-27.6 0l-40 66.49l-46.91-23.37A16.1 16.1 0 0 0 4.82 90.35l37 113.35a12 12 0 0 0 17.51 6.61C59.57 210.17 84.39 196 128 196s68.43 14.19 68.62 14.3a12 12 0 0 0 17.57-6.58l37-113.29a16 16 0 0 0-4.73-17.26Zm-50.93 110.35C182.18 178.4 159.2 172 128 172s-54.18 6.42-67.53 11.54l-27-82.71L70 119a16.19 16.19 0 0 0 21-6.11l37-61.49l37 61.5a16.18 16.18 0 0 0 21 6.1l36.52-18.2Z" />
                  </svg>
                </span>
              {{/if}}
              <img src={{row.avatar_url}} alt={{row.display_name}} />
              <span class="westan-ranking-podium__position">{{row.position}}</span>
            </div>
            <strong>{{row.display_name}}</strong>
            <em>@{{row.username}}</em>
            <div class="westan-ranking-podium__score">
              <span>{{row.total_points}}</span> pontos
            </div>
          </article>
        {{/each}}
      </section>

      <div class="westan-ranking-hero__meta">
        <span>{{dIcon "calendar-days"}} {{this.periodLabel}}</span>
        <span>{{dIcon "wand-magic-sparkles"}} {{this.updateLabel}}</span>
      </div>

      <section class="westan-ranking-current" aria-label="Sua posição no ranking">
        {{#if this.currentUserRank}}
          <div class="westan-ranking-current__user">
            <img src={{this.currentUserRank.avatar_url}} alt={{this.currentUserRank.display_name}} />
            <div>
              <span>Sua posição</span>
              <strong>{{this.currentUserRank.display_name}}</strong>
            </div>
          </div>
          <b>#{{this.currentUserRank.position}}</b>
          <div class="westan-ranking-current__points">
            <strong>{{this.currentUserRank.total_points}}</strong>
            <span>pontos</span>
          </div>
        {{else if this.currentUser}}
          <div class="westan-ranking-current__empty">
            <span>Sua posição</span>
            <strong>Você ainda não pontuou neste período.</strong>
          </div>
        {{else}}
          <div class="westan-ranking-current__empty">
            <span>Sua posição</span>
            <strong>Entre para acompanhar seu desempenho.</strong>
          </div>
          <a href="/login">Entrar</a>
        {{/if}}
      </section>

      {{#if this.hasListRows}}
        <section class="westan-ranking-list" aria-label="Demais posições do ranking">
          <header>
            <h2>Demais posições</h2>
            <span>Top 20</span>
          </header>
          {{#each this.listRows as |row|}}
            <article class="westan-ranking-list__row">
              <b>#{{row.position}}</b>
              <img src={{row.avatar_url}} alt={{row.display_name}} />
              <div class="westan-ranking-list__user">
                <strong>{{row.display_name}}</strong>
                <span>@{{row.username}}</span>
              </div>
              <div class="westan-ranking-list__activity">
                <span><strong>{{row.posts_count}}</strong> posts</span>
                <span><strong>{{row.topics_count}}</strong> tópicos</span>
              </div>
              <div class="westan-ranking-list__points">
                <strong>{{row.total_points}}</strong>
                <span>pontos</span>
              </div>
            </article>
          {{/each}}
        </section>
      {{/if}}
    {{else}}
      <div class="westan-ranking-empty">Ainda não há membros para exibir neste período.</div>
    {{/if}}

    {{#if this.showInfo}}
      <div class="westan-ranking-modal" role="dialog" aria-modal="true" aria-labelledby="westan-ranking-info-title">
        <button type="button" class="westan-ranking-modal__backdrop" aria-label="Fechar" {{on "click" this.closeInfo}}></button>
        <div class="westan-ranking-modal__panel westan-ranking-info">
          <button type="button" class="westan-ranking-modal__close" aria-label="Fechar" {{on "click" this.closeInfo}}>
            {{dIcon "xmark"}}
          </button>
          <p>Ranking Westan</p>
          <h2 id="westan-ranking-info-title">Como a pontuação funciona</h2>
          <div>
            O ranking semanal considera a última semana completa e é renovado às segundas-feiras. O ranking mensal acompanha a participação no mês atual.
            A pontuação usa <strong>1 post = {{this.pointsPerPost}} ponto</strong> e
            <strong>1 tópico = {{this.pointsPerTopic}} pontos</strong>.
            Membros do grupo VIP recebem multiplicador de até <strong>x{{this.vipMultiplierCap}}</strong>.
          </div>
        </div>
      </div>
    {{/if}}

    {{#if this.showSettings}}
      <div class="westan-ranking-modal" role="dialog" aria-modal="true" aria-labelledby="westan-ranking-settings-title">
        <button type="button" class="westan-ranking-modal__backdrop" aria-label="Fechar" {{on "click" this.closeSettings}}></button>
        <div class="westan-ranking-modal__panel westan-ranking-settings">
          <button type="button" class="westan-ranking-modal__close" aria-label="Fechar" {{on "click" this.closeSettings}}>
            {{dIcon "xmark"}}
          </button>
          <h2 id="westan-ranking-settings-title">Configurações do Ranking</h2>

          <p class="westan-ranking-settings__hint">O período personalizado abaixo afeta somente o ranking semanal.</p>
          <div class="westan-ranking-settings__grid">
            <label>
              <span>Início</span>
              <input type="date" value={{this.draft.period_start}} data-field="period_start" {{on "input" this.updateDraft}} />
            </label>
            <label>
              <span>Fim</span>
              <input type="date" value={{this.draft.period_end}} data-field="period_end" {{on "input" this.updateDraft}} />
            </label>
          </div>
          <button type="button" class="westan-ranking-settings__link" {{on "click" this.resetPeriod}}>Restaurar automático</button>

          <div class="westan-ranking-settings__grid">
            <label>
              <span>Pontos por post</span>
              <input type="number" min="0" max="10" value={{this.draft.points_per_post}} data-field="points_per_post" {{on "input" this.updateDraftNumber}} />
            </label>
            <label>
              <span>Pontos por tópico</span>
              <input type="number" min="0" max="10" value={{this.draft.points_per_topic}} data-field="points_per_topic" {{on "input" this.updateDraftNumber}} />
            </label>
          </div>

          <label>
            <span>Limite multiplicador VIP</span>
            <input type="number" min="1" max="10" value={{this.draft.vip_multiplier_cap}} data-field="vip_multiplier_cap" {{on "input" this.updateDraftNumber}} />
          </label>

          <label>
            <span>Remover membro do ranking</span>
            <div class="westan-ranking-search">
              {{dIcon "magnifying-glass"}}
              <input type="text" placeholder="Buscar usuário..." value={{this.userSearch}} {{on "input" this.searchUsers}} />
            </div>
          </label>

          <div class="westan-ranking-settings__users">
            {{#each this.userResultRows as |user|}}
              <div>
                <img src={{user.avatar_url}} alt={{user.display_name}} />
                <span><strong>{{user.display_name}}</strong><em>@{{user.username}}</em></span>
                {{#if user.is_excluded}}
                  <button type="button" data-user-id={{user.id}} {{on "click" this.includeUser}}>Reincluir</button>
                {{else}}
                  <button type="button" class="is-danger" data-user-id={{user.id}} {{on "click" this.excludeUser}}>{{dIcon "trash-can"}} Remover</button>
                {{/if}}
              </div>
            {{/each}}
          </div>

          <footer>
            <button type="button" {{on "click" this.closeSettings}}>Cancelar</button>
            <button type="button" class="is-primary" disabled={{this.isSaving}} {{on "click" this.saveSettings}}>
              {{if this.isSaving "Salvando..." "Salvar"}}
            </button>
          </footer>
        </div>
      </div>
    {{/if}}
  </template>
}
