#include <gtk/gtk.h>
#include <glib-unix.h>
#include <errno.h>
#include <signal.h>
#include <unistd.h>
#include <utime.h>
#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define APP_ID "rice.theme-picker"
#define MAX_THEMES 64

typedef struct {
    char *name;
    char *hex;
    char *desc;
} Theme;

typedef struct {
    GtkApplication *app;
    GtkWidget *listbox;
    GtkWidget *main_window;
    GtkWidget *osd_box;
    GtkWidget *osd_label;
    GtkCssProvider *style_provider;
    guint osd_hide_source;
    Theme themes[MAX_THEMES];
    int theme_count;
    char *original;
    char *previewed;
    gboolean committed;
    gboolean ready;
    char *script_path;
    char *themes_file;
    char *hypr_theme_file;
    char *waybar_theme_file;
    char *waybar_style_file;
    char *zed_theme_file;
    char *swayosd_theme_file;
    char *lock_file;
} State;


static char *trim(char *s) {
    while (isspace((unsigned char)*s)) s++;
    if (*s == 0) return s;
    char *end = s + strlen(s) - 1;
    while (end > s && isspace((unsigned char)*end)) *end-- = 0;
    return s;
}

static void free_themes(State *st) {
    for (int i = 0; i < st->theme_count; i++) {
        g_free(st->themes[i].name);
        g_free(st->themes[i].hex);
        g_free(st->themes[i].desc);
    }
    st->theme_count = 0;
}

static void load_themes(State *st) {
    gchar *contents = NULL;
    gsize len = 0;
    if (!g_file_get_contents(st->themes_file, &contents, &len, NULL)) return;

    char *save = NULL;
    for (char *line = strtok_r(contents, "\n", &save);
         line && st->theme_count < MAX_THEMES;
         line = strtok_r(NULL, "\n", &save)) {
        char *t = trim(line);
        if (*t == 0 || *t == '#') continue;

        char *name = strtok(t, "\t");
        char *hex = strtok(NULL, "\t");
        char *desc = strtok(NULL, "\t");
        if (!name || !hex) continue;

        st->themes[st->theme_count].name = g_strdup(trim(name));
        st->themes[st->theme_count].hex = g_strdup(trim(hex));
        st->themes[st->theme_count].desc = g_strdup(desc ? trim(desc) : "");
        st->theme_count++;
    }
    g_free(contents);
}

static char *current_theme(State *st) {
    gchar *contents = NULL;
    gsize len = 0;
    if (g_file_get_contents(st->hypr_theme_file, &contents, &len, NULL)) {
        char *save = NULL;
        for (char *line = strtok_r(contents, "\n", &save); line; line = strtok_r(NULL, "\n", &save)) {
            if (g_str_has_prefix(line, "$theme_name") && strchr(line, '=')) {
                char *value = trim(strchr(line, '=') + 1);
                char *out = g_strdup(value);
                g_free(contents);
                return out;
            }
        }
        g_free(contents);
    }
    return st->theme_count ? g_strdup(st->themes[0].name) : g_strdup("Blue");
}

static const char *hex_for_theme(State *st, const char *name) {
    for (int i = 0; i < st->theme_count; i++) {
        if (g_strcmp0(st->themes[i].name, name) == 0) return st->themes[i].hex;
    }
    return st->theme_count ? st->themes[0].hex : "005577";
}



static void hex_to_rgb(const char *hex, int *r, int *g, int *b) {
    char part[3] = {0};
    if (!hex || strlen(hex) < 6) {
        *r = 0; *g = 85; *b = 119;
        return;
    }
    part[0] = hex[0]; part[1] = hex[1]; *r = (int)strtol(part, NULL, 16);
    part[0] = hex[2]; part[1] = hex[3]; *g = (int)strtol(part, NULL, 16);
    part[0] = hex[4]; part[1] = hex[5]; *b = (int)strtol(part, NULL, 16);
}


static char *replace_all_literal(const char *text, const char *needle, const char *replacement) {
    if (!text || !needle || !*needle || !replacement) return g_strdup(text ? text : "");
    char **parts = g_strsplit(text, needle, -1);
    char *joined = g_strjoinv(replacement, parts);
    g_strfreev(parts);
    return joined;
}

static void rewrite_zed_theme_file(State *st, const char *hex) {
    if (!st->zed_theme_file || !hex || !*hex) return;
    gchar *contents = NULL;
    if (!g_file_get_contents(st->zed_theme_file, &contents, NULL, NULL)) return;

    char *updated = g_strdup(contents);
    const char *suffixes[] = { "88", "66", "", NULL };
    for (int i = 0; i < st->theme_count; i++) {
        const char *old_hex = st->themes[i].hex;
        if (!old_hex || !*old_hex) continue;
        for (int j = 0; suffixes[j] != NULL; j++) {
            char *needle = g_strdup_printf("#%s%s", old_hex, suffixes[j]);
            char *replacement = g_strdup_printf("#%s%s", hex, suffixes[j]);
            char *next = replace_all_literal(updated, needle, replacement);
            g_free(updated);
            updated = next;
            g_free(needle);
            g_free(replacement);
        }
    }

    FILE *fp = fopen(st->zed_theme_file, "w");
    if (fp) {
        fputs(updated, fp);
        fclose(fp);
    }
    g_free(updated);
    g_free(contents);
}

static void write_preview_theme_files(State *st, const char *name) {
    const char *hex = hex_for_theme(st, name);
    if (!hex || !*hex) return;
    int r, g, b;
    hex_to_rgb(hex, &r, &g, &b);

    char *waybar = g_strdup_printf(
        "/* Generated by ~/.config/hypr/scripts/theme-picker */\n"
        "/* Preview theme: %s */\n"
        "@define-color col_cyan #%s;\n",
        name, hex);
    g_file_set_contents(st->waybar_theme_file, waybar, -1, NULL);
    g_free(waybar);

    char *swayosd = g_strdup_printf(
        "/* Generated by ~/.config/hypr/scripts/theme-picker */\n"
        "/* Preview theme: %s */\n"
        "@define-color osd_accent #%s;\n"
        "@define-color osd_accent_soft rgba(%d, %d, %d, 0.45);\n"
        "@define-color osd_accent_bar rgba(%d, %d, %d, 0.95);\n",
        name, hex, r, g, b, r, g, b);
    g_file_set_contents(st->swayosd_theme_file, swayosd, -1, NULL);
    g_free(swayosd);

    gchar *style = NULL;
    if (g_file_get_contents(st->waybar_style_file, &style, NULL, NULL)) {
        char *replacement = g_strdup_printf("@define-color col_cyan #%s;", hex);
        char **lines = g_strsplit(style, "\n", -1);
        GString *out = g_string_new(NULL);
        gboolean replaced = FALSE;
        for (int i = 0; lines[i] != NULL; i++) {
            if (g_str_has_prefix(lines[i], "@define-color col_cyan ")) {
                g_string_append(out, replacement);
                replaced = TRUE;
            } else {
                g_string_append(out, lines[i]);
            }
            if (lines[i + 1] != NULL) g_string_append_c(out, '\n');
        }
        if (!replaced) {
            if (out->len > 0 && out->str[out->len - 1] != '\n') g_string_append_c(out, '\n');
            g_string_append(out, replacement);
            g_string_append_c(out, '\n');
        }
        FILE *fp = fopen(st->waybar_style_file, "w");
        if (fp) {
            fputs(out->str, fp);
            fclose(fp);
        }
        g_string_free(out, TRUE);
        g_strfreev(lines);
        g_free(replacement);
        g_free(style);
    }

    rewrite_zed_theme_file(st, hex);
}

static void update_css(State *st, const char *hex) {
    int r, g, b;
    hex_to_rgb(hex, &r, &g, &b);
    char *css = g_strdup_printf(
        "window { background: #222222; }"
        "#root { background: #222222; padding: 10px 14px; }"
        "label { color: #eeeeee; font-family: 'JetBrains Mono Nerd Font', monospace; font-size: 14px; }"
        "#prompt { color: #%s; padding: 0 0 8px 0; }"
        "list { background: #222222; }"
        "row { padding: 7px 10px; background: #222222; border-radius: 0; }"
        "row:hover, row:selected { background: #%s; }"
        "row:hover label, row:selected label { color: #eeeeee; }"
        "#osdpreview { background: rgba(22,22,26,0.82); border: 1px solid rgba(%d,%d,%d,0.45); border-radius: 22px; padding: 14px 18px; }"
        "#osdlabel { color: rgba(255,255,255,0.96); font-weight: 600; font-size: 15px; }"
        "progressbar trough { min-height: 7px; border-radius: 999px; background: rgba(255,255,255,0.28); }"
        "progressbar progress { min-height: 7px; border-radius: 999px; background: rgba(%d,%d,%d,0.95); }",
        hex, hex, r, g, b, r, g, b);
    gtk_css_provider_load_from_string(st->style_provider, css);
    g_free(css);
}

static void show_osd_preview(State *st, const char *name) {
    const char *hex = hex_for_theme(st, name);
    if (!hex || !*hex || !st->osd_box) return;

    char *label = g_strdup_printf("󰕾  %s  volume/brightness preview", name);
    gtk_label_set_text(GTK_LABEL(st->osd_label), label);
    g_free(label);

    gtk_widget_set_visible(st->osd_box, TRUE);
}

static void run_theme(State *st, const char *mode, const char *name);

static void live_preview_theme(State *st, const char *name) {
    const char *hex = hex_for_theme(st, name);
    if (!hex || !*hex) return;

    write_preview_theme_files(st, name);
    update_css(st, hex);
    show_osd_preview(st, name);
    run_theme(st, "--preview", name);

    char *batch = g_strdup_printf(
        "keyword general:col.active_border rgba(%sff); keyword decoration:shadow:color rgb(%s)",
        hex, hex);
    char *argv[] = { "hyprctl", "--batch", batch, NULL };
    g_spawn_async(NULL, argv, NULL, G_SPAWN_SEARCH_PATH, NULL, NULL, NULL, NULL);
    g_free(batch);
}

static void run_theme(State *st, const char *mode, const char *name) {
    if (!name || !*name) return;
    char *argv[] = { st->script_path, (char *)mode, (char *)name, NULL };
    g_spawn_async(NULL, argv, NULL, G_SPAWN_SEARCH_PATH, NULL, NULL, NULL, NULL);
}

static void preview_theme(State *st, const char *name) {
    if (!st->ready || !name) return;
    if (st->previewed && g_strcmp0(st->previewed, name) == 0) return;
    g_free(st->previewed);
    st->previewed = g_strdup(name);
    live_preview_theme(st, name);
}

static void commit_theme(State *st, const char *name) {
    if (!name) return;
    st->committed = TRUE;
    run_theme(st, "--apply", name);
    g_application_quit(G_APPLICATION(st->app));
}

static void restore_if_needed(State *st) {
    if (!st->committed && st->original) live_preview_theme(st, st->original);
}

static void on_motion_enter(GtkEventControllerMotion *motion, double x, double y, gpointer user_data) {
    (void)motion; (void)x; (void)y;
    GtkListBoxRow *row = GTK_LIST_BOX_ROW(user_data);
    State *st = g_object_get_data(G_OBJECT(row), "state");
    const char *name = g_object_get_data(G_OBJECT(row), "theme-name");
    gtk_list_box_select_row(GTK_LIST_BOX(st->listbox), row);
    preview_theme(st, name);
}

static void on_row_selected(GtkListBox *box, GtkListBoxRow *row, gpointer user_data) {
    (void)box;
    State *st = user_data;
    if (!row) return;
    const char *name = g_object_get_data(G_OBJECT(row), "theme-name");
    preview_theme(st, name);
}

static void on_row_activated(GtkListBox *box, GtkListBoxRow *row, gpointer user_data) {
    (void)box;
    State *st = user_data;
    const char *name = g_object_get_data(G_OBJECT(row), "theme-name");
    commit_theme(st, name);
}

static gboolean on_key_pressed(GtkEventControllerKey *controller, guint keyval, guint keycode, GdkModifierType state_mods, gpointer user_data) {
    (void)controller; (void)keycode; (void)state_mods;
    State *st = user_data;
    if (keyval == GDK_KEY_Escape) {
        restore_if_needed(st);
        g_application_quit(G_APPLICATION(st->app));
        return TRUE;
    }
    return FALSE;
}

static gboolean on_close_request(GtkWindow *window, gpointer user_data) {
    (void)window;
    restore_if_needed(user_data);
    return FALSE;
}


static gboolean on_terminate_signal(gpointer user_data) {
    State *st = user_data;
    restore_if_needed(st);
    g_application_quit(G_APPLICATION(st->app));
    return G_SOURCE_REMOVE;
}

static gboolean lock_or_toggle(State *st) {
    const char *runtime = g_getenv("XDG_RUNTIME_DIR");
    if (!runtime || !*runtime) runtime = "/tmp";
    st->lock_file = g_build_filename(runtime, "hypr-theme-picker.pid", NULL);

    gchar *contents = NULL;
    if (g_file_get_contents(st->lock_file, &contents, NULL, NULL)) {
        char *end = NULL;
        long old_pid = strtol(contents, &end, 10);
        g_free(contents);
        if (old_pid > 1 && kill((pid_t)old_pid, 0) == 0) {
            kill((pid_t)old_pid, SIGTERM);
            g_unlink(st->lock_file);
            return FALSE;
        }
        g_unlink(st->lock_file);
    }

    char pid_buf[32];
    g_snprintf(pid_buf, sizeof(pid_buf), "%ld\n", (long)getpid());
    g_file_set_contents(st->lock_file, pid_buf, -1, NULL);
    return TRUE;
}

static void cleanup_lock(State *st) {
    if (st->lock_file) {
        g_unlink(st->lock_file);
    }
}


static gboolean mark_ready(gpointer user_data) {
    State *st = user_data;
    st->ready = TRUE;
    return G_SOURCE_REMOVE;
}

static void activate(GtkApplication *app, gpointer user_data) {
    State *st = user_data;
    if (st->theme_count == 0) return;

    const char *active_hex = hex_for_theme(st, st->original);
    st->style_provider = gtk_css_provider_new();
    update_css(st, active_hex);
    gtk_style_context_add_provider_for_display(gdk_display_get_default(), GTK_STYLE_PROVIDER(st->style_provider), GTK_STYLE_PROVIDER_PRIORITY_APPLICATION);

    GtkWidget *win = gtk_application_window_new(app);
    st->main_window = win;
    gtk_window_set_title(GTK_WINDOW(win), "theme");
    gtk_window_set_decorated(GTK_WINDOW(win), FALSE);
    gtk_window_set_resizable(GTK_WINDOW(win), FALSE);
    gtk_window_set_default_size(GTK_WINDOW(win), 580, 420);
    g_signal_connect(win, "close-request", G_CALLBACK(on_close_request), st);

    GtkEventController *keys = gtk_event_controller_key_new();
    gtk_event_controller_set_propagation_phase(keys, GTK_PHASE_CAPTURE);
    g_signal_connect(keys, "key-pressed", G_CALLBACK(on_key_pressed), st);
    gtk_widget_add_controller(win, keys);

    GtkWidget *root = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0);
    gtk_widget_set_name(root, "root");
    gtk_window_set_child(GTK_WINDOW(win), root);

    GtkWidget *prompt = gtk_label_new("theme> hover previews · enter/click applies · esc cancels");
    gtk_widget_set_name(prompt, "prompt");
    gtk_label_set_xalign(GTK_LABEL(prompt), 0.0f);
    gtk_box_append(GTK_BOX(root), prompt);

    st->listbox = gtk_list_box_new();
    gtk_list_box_set_selection_mode(GTK_LIST_BOX(st->listbox), GTK_SELECTION_SINGLE);
    g_signal_connect(st->listbox, "row-selected", G_CALLBACK(on_row_selected), st);
    g_signal_connect(st->listbox, "row-activated", G_CALLBACK(on_row_activated), st);
    gtk_box_append(GTK_BOX(root), st->listbox);

    st->osd_box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 8);
    gtk_widget_set_name(st->osd_box, "osdpreview");
    gtk_widget_set_visible(st->osd_box, TRUE);
    char *initial_osd_label = g_strdup_printf("󰕾  %s  volume/brightness preview", st->original);
    st->osd_label = gtk_label_new(initial_osd_label);
    g_free(initial_osd_label);
    gtk_widget_set_name(st->osd_label, "osdlabel");
    gtk_label_set_xalign(GTK_LABEL(st->osd_label), 0.0f);
    gtk_box_append(GTK_BOX(st->osd_box), st->osd_label);
    GtkWidget *bar = gtk_progress_bar_new();
    gtk_progress_bar_set_fraction(GTK_PROGRESS_BAR(bar), 0.65);
    gtk_box_append(GTK_BOX(st->osd_box), bar);
    gtk_box_append(GTK_BOX(root), st->osd_box);

    GtkListBoxRow *original_row = NULL;
    for (int i = 0; i < st->theme_count; i++) {
        Theme *th = &st->themes[i];
        GtkWidget *row = gtk_list_box_row_new();
        GtkWidget *row_box = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 8);
        GtkWidget *swatch = gtk_label_new(NULL);
        char *swatch_markup = g_strdup_printf("<span foreground=\"#%s\">■</span>", th->hex);
        gtk_label_set_markup(GTK_LABEL(swatch), swatch_markup);
        g_free(swatch_markup);
        const char *marker = g_strcmp0(th->name, st->original) == 0 ? "● " : "  ";
        char *text = g_strdup_printf("%s%-8s #%s  %s", marker, th->name, th->hex, th->desc);
        GtkWidget *label = gtk_label_new(text);
        g_free(text);
        gtk_label_set_xalign(GTK_LABEL(label), 0.0f);
        gtk_box_append(GTK_BOX(row_box), swatch);
        gtk_box_append(GTK_BOX(row_box), label);
        gtk_list_box_row_set_child(GTK_LIST_BOX_ROW(row), row_box);

        g_object_set_data(G_OBJECT(row), "state", st);
        g_object_set_data_full(G_OBJECT(row), "theme-name", g_strdup(th->name), g_free);

        GtkEventController *motion = gtk_event_controller_motion_new();
        g_signal_connect(motion, "enter", G_CALLBACK(on_motion_enter), row);
        gtk_widget_add_controller(row, motion);

        gtk_list_box_append(GTK_LIST_BOX(st->listbox), row);
        if (g_strcmp0(th->name, st->original) == 0) original_row = GTK_LIST_BOX_ROW(row);
    }

    if (original_row) gtk_list_box_select_row(GTK_LIST_BOX(st->listbox), original_row);

    gtk_window_present(GTK_WINDOW(win));
    g_timeout_add(150, mark_ready, st);
}

int main(int argc, char **argv) {
    State st = {0};
    const char *home = g_get_home_dir();
    st.themes_file = g_build_filename(home, ".config/hypr/themes/themes.tsv", NULL);
    st.hypr_theme_file = g_build_filename(home, ".config/hypr/themes/hypr.conf", NULL);
    st.waybar_theme_file = g_build_filename(home, ".config/hypr/themes/waybar.css", NULL);
    st.waybar_style_file = g_build_filename(home, ".config/waybar/style.css", NULL);
    st.zed_theme_file = g_build_filename(home, ".config/zed/themes/dwm-hyprland.json", NULL);
    st.swayosd_theme_file = g_build_filename(home, ".config/hypr/themes/swayosd.css", NULL);
    st.script_path = g_build_filename(home, ".config/hypr/scripts/theme-picker", NULL);
    if (!lock_or_toggle(&st)) {
        g_free(st.script_path);
        g_free(st.themes_file);
        g_free(st.hypr_theme_file);
        g_free(st.waybar_theme_file);
        g_free(st.waybar_style_file);
        g_free(st.zed_theme_file);
        g_free(st.swayosd_theme_file);
        g_free(st.lock_file);
        return 0;
    }

    load_themes(&st);
    st.original = current_theme(&st);
    st.previewed = g_strdup(st.original);

    st.app = gtk_application_new(APP_ID, G_APPLICATION_NON_UNIQUE);
    g_unix_signal_add(SIGTERM, on_terminate_signal, &st);
    g_signal_connect(st.app, "activate", G_CALLBACK(activate), &st);
    int status = g_application_run(G_APPLICATION(st.app), argc, argv);

    cleanup_lock(&st);
    if (st.style_provider) g_object_unref(st.style_provider);
    g_object_unref(st.app);
    free_themes(&st);
    g_free(st.original);
    g_free(st.previewed);
    g_free(st.script_path);
    g_free(st.themes_file);
    g_free(st.hypr_theme_file);
    g_free(st.waybar_theme_file);
    g_free(st.waybar_style_file);
    g_free(st.zed_theme_file);
    g_free(st.swayosd_theme_file);
    g_free(st.lock_file);
    return status;
}
