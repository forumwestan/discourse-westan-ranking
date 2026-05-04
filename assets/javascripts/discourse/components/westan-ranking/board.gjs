import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { on } from "@ember/modifier";
import { ajax } from "discourse/lib/ajax";
import dIcon from "discourse/helpers/d-icon";

export default class WestanRankingBoard extends Component {
  @service currentUser;

  @tracked rows = this.args.model.rows || [];
  @tracked config = this.args.model.config || {};
  @tracked period = this.args.model.period || {};
  @tracked showInfo = false;
  @tracked showSettings = false;
  @tracked draft = { ...this.config };
  @tracked userSearch = "";
  @tracked userResults = [];
  @tracked isSaving = false;

  get canManage() {
    return this.currentUser?.admin || this.currentUser?.moderator;
  }

  get excludedUserIds() {
    return this.draft.excluded_user_ids || [];
  }

  get hasRows() {
    return this.rows.length > 0;
  }

  get displayRows() {
    return this.rows.map((row, index) => ({
      ...row,
      is_winner: index === 0,
    }));
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
  openSettings() {
    this.draft = { ...this.config, excluded_user_ids: [...(this.config.excluded_user_ids || [])] };
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
    this.rows = refreshed.rows || [];
    this.config = refreshed.config || {};
    this.period = refreshed.period || {};
    this.isSaving = false;
    this.showSettings = false;
  }

  <template>
    <section class="westan-ranking-hero">
      <p>Ranking Semanal</p>
      <div class="westan-ranking-hero__topline">
        <h1>Usuários mais engajados da comunidade</h1>
        <div class="westan-ranking-hero__actions">
          {{#if this.canManage}}
            <button type="button" class="westan-ranking-icon-button" aria-label="Configurações do ranking" {{on "click" this.openSettings}}>
              {{dIcon "gear"}}
            </button>
          {{/if}}
          <button type="button" class="westan-ranking-icon-button westan-ranking-icon-button--accent" aria-label="Ver detalhes do ranking" {{on "click" this.openInfo}}>
            {{dIcon "circle-info"}}
          </button>
        </div>
      </div>

      <div class="westan-ranking-hero__meta">
        <span>{{dIcon "calendar-days"}} Semana válida: {{this.period.label}}</span>
        <span>{{dIcon "wand-magic-sparkles"}} Atualiza às segundas-feiras</span>
      </div>
    </section>

    <section class="westan-ranking-table" aria-label="Ranking Semanal">
      <div class="westan-ranking-table__head">
        <span>Posição</span>
        <span>Usuário</span>
        <span>Posts</span>
        <span>Tópicos</span>
        <span>VIP</span>
        <span>Pontos</span>
      </div>

      {{#if this.hasRows}}
        {{#each this.displayRows as |row|}}
          <article class="westan-ranking-row">
            <div class="westan-ranking-position">#{{row.position}}</div>
            <div class="westan-ranking-user">
              <div class="westan-ranking-avatar">
                <img src={{row.avatar_url}} alt={{row.display_name}} />
                {{#if row.is_winner}}
                  <span>{{dIcon "crown"}}</span>
                {{/if}}
              </div>
              <div>
                <strong>{{row.display_name}}</strong>
                <em>@{{row.username}}</em>
              </div>
            </div>
            <div class="westan-ranking-pill">{{row.posts_count}}</div>
            <div class="westan-ranking-pill">{{row.topics_count}}</div>
            <div class="westan-ranking-pill westan-ranking-pill--vip">
              <strong>x{{row.vip_multiplier}}</strong>
              <small>{{if row.is_vip "VIP ativo" "Padrão"}}</small>
            </div>
            <div class="westan-ranking-pill westan-ranking-pill--points">
              <strong>{{row.total_points}}</strong>
              <small>{{row.base_points}} base</small>
            </div>
          </article>
        {{/each}}
      {{else}}
        <div class="westan-ranking-empty">Ainda não há membros para exibir no ranking.</div>
      {{/if}}
    </section>

    {{#if this.showInfo}}
      <div class="westan-ranking-modal" role="dialog" aria-modal="true">
        <button type="button" class="westan-ranking-modal__backdrop" aria-label="Fechar" {{on "click" this.closeInfo}}></button>
        <div class="westan-ranking-modal__panel westan-ranking-info">
          <button type="button" class="westan-ranking-modal__close" aria-label="Fechar" {{on "click" this.closeInfo}}>
            {{dIcon "xmark"}}
          </button>
          <p>Ranking Semanal</p>
          <h2>Como a pontuação funciona</h2>
          <div>
            O ranking é renovado automaticamente toda segunda-feira e considera todos os membros do fórum na semana anterior.
            A pontuação usa <strong>1 post = {{this.pointsPerPost}} ponto</strong> e
            <strong>1 tópico = {{this.pointsPerTopic}} pontos</strong>.
            O status VIP dobra a pontuação final (multiplicador <strong>x{{this.vipMultiplierCap}}</strong>).
          </div>
        </div>
      </div>
    {{/if}}

    {{#if this.showSettings}}
      <div class="westan-ranking-modal" role="dialog" aria-modal="true">
        <button type="button" class="westan-ranking-modal__backdrop" aria-label="Fechar" {{on "click" this.closeSettings}}></button>
        <div class="westan-ranking-modal__panel westan-ranking-settings">
          <button type="button" class="westan-ranking-modal__close" aria-label="Fechar" {{on "click" this.closeSettings}}>
            {{dIcon "xmark"}}
          </button>
          <h2>Configurações do Ranking</h2>

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
