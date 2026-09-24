#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include "flutter/generated_plugin_registrant.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
  FlMethodChannel* window_channel;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

static gboolean has_argument(char** arguments, const gchar* argument) {
  for (char** it = arguments; it != nullptr && *it != nullptr; it++) {
    if (g_strcmp0(*it, argument) == 0) {
      return TRUE;
    }
  }
  return FALSE;
}

#ifdef GDK_WINDOWING_X11
// Asks the window manager to activate the window on behalf of the desktop
// shell (source indication 2, "pager"), the same request a taskbar sends.
// Unlike requests from the application itself, window managers such as
// KWin honor it even when focus stealing prevention would block the app.
static void request_x11_activation(GdkWindow* gdk_window, guint32 timestamp) {
  Display* display = GDK_DISPLAY_XDISPLAY(gdk_window_get_display(gdk_window));
  XEvent event = {};
  event.xclient.type = ClientMessage;
  event.xclient.send_event = True;
  event.xclient.display = display;
  event.xclient.window = GDK_WINDOW_XID(gdk_window);
  event.xclient.message_type =
      XInternAtom(display, "_NET_ACTIVE_WINDOW", False);
  event.xclient.format = 32;
  event.xclient.data.l[0] = 2;
  event.xclient.data.l[1] = timestamp;
  XSendEvent(display, DefaultRootWindow(display), False,
             SubstructureRedirectMask | SubstructureNotifyMask, &event);
  XFlush(display);
}
#endif

// Brings the window to the front, using the activation token handed over
// by the tray host when there is one.
static void activate_window(GtkWindow* window, const gchar* token) {
  if (token != nullptr && *token != '\0') {
    gtk_window_set_startup_id(window, token);
  }

#ifdef GDK_WINDOWING_X11
  GdkWindow* gdk_window = gtk_widget_get_window(GTK_WIDGET(window));
  if (gdk_window != nullptr && GDK_IS_X11_WINDOW(gdk_window)) {
    guint32 timestamp = gdk_x11_get_server_time(gdk_window);
    gdk_x11_window_set_user_time(gdk_window, timestamp);

    // Only windows the window manager already manages can be activated;
    // KWin fails to map a window that receives the request too early.
    XWindowAttributes attributes;
    Display* display =
        GDK_DISPLAY_XDISPLAY(gdk_window_get_display(gdk_window));
    if (XGetWindowAttributes(display, GDK_WINDOW_XID(gdk_window),
                             &attributes) != 0 &&
        attributes.map_state == IsViewable) {
      request_x11_activation(gdk_window, timestamp);
      return;
    }
    gtk_window_present_with_time(window, timestamp);
    return;
  }
#endif
  gtk_window_present(window);
}

// Handles calls on the "desktop/window" channel.
static void window_method_call_cb(FlMethodChannel* channel,
                                  FlMethodCall* method_call,
                                  gpointer user_data) {
  GtkWindow* window = GTK_WINDOW(user_data);
  g_autoptr(FlMethodResponse) response = nullptr;

  if (g_strcmp0(fl_method_call_get_name(method_call), "activate") == 0) {
    FlValue* args = fl_method_call_get_args(method_call);
    const gchar* token = nullptr;
    if (args != nullptr && fl_value_get_type(args) == FL_VALUE_TYPE_STRING) {
      token = fl_value_get_string(args);
    }
    activate_window(window, token);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  fl_method_call_respond(method_call, response, nullptr);
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

  // Use a header bar when running in GNOME as this is the common style used
  // by applications and is the setup most users will be using (e.g. Ubuntu
  // desktop).
  // If running on X and not using GNOME then just use a traditional title bar
  // in case the window manager does more exotic layout, e.g. tiling.
  // If running on Wayland assume the header bar will work (may need changing
  // if future cases occur).
  gboolean use_header_bar = TRUE;
#ifdef GDK_WINDOWING_X11
  GdkScreen* screen = gtk_window_get_screen(window);
  if (GDK_IS_X11_SCREEN(screen)) {
    const gchar* wm_name = gdk_x11_screen_get_window_manager_name(screen);
    if (g_strcmp0(wm_name, "GNOME Shell") != 0) {
      use_header_bar = FALSE;
    }
  }
#endif
  if (use_header_bar) {
    GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_widget_show(GTK_WIDGET(header_bar));
    gtk_header_bar_set_title(header_bar, "Meu Trello Local");
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  } else {
    gtk_window_set_title(window, "Meu Trello Local");
  }

  // Use the icon bundled with the Flutter assets, so the window has the app
  // icon even when no desktop entry has been installed.
  g_autofree gchar* executable = g_file_read_link("/proc/self/exe", nullptr);
  if (executable != nullptr) {
    g_autofree gchar* directory = g_path_get_dirname(executable);
    g_autofree gchar* icon = g_build_filename(
        directory, "data", "flutter_assets", "assets", "icon", "app_icon.png",
        nullptr);
    gtk_window_set_icon_from_file(window, icon, nullptr);
  }

  gtk_window_set_default_size(window, 1200, 760);
  gtk_window_set_position(window, GTK_WIN_POS_CENTER);
  // With --hidden the app starts in the system tray: realize the window so
  // it can be shown later, without mapping it now.
  if (has_argument(self->dart_entrypoint_arguments, "--hidden")) {
    gtk_widget_realize(GTK_WIDGET(window));
  } else {
    gtk_widget_show(GTK_WIDGET(window));
  }

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  g_autoptr(FlPluginRegistrar) registrar =
      fl_plugin_registry_get_registrar_for_plugin(FL_PLUGIN_REGISTRY(view),
                                                  "DesktopWindow");
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_clear_object(&self->window_channel);
  self->window_channel = fl_method_channel_new(
      fl_plugin_registrar_get_messenger(registrar), "desktop/window",
      FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(
      self->window_channel, window_method_call_cb, window, nullptr);

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application, gchar*** arguments, int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  // Strip out the first argument as it is the binary name.
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
     g_warning("Failed to register: %s", error->message);
     *exit_status = 1;
     return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  //MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application startup.

  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  //MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application shutdown.

  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  g_clear_object(&self->window_channel);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line = my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {}

MyApplication* my_application_new() {
  // Set the program name to the application ID, which helps various systems
  // like GTK and desktop environments map this running application to its
  // corresponding .desktop file. This ensures better integration by allowing
  // the application to be recognized beyond its binary name.
  g_set_prgname(APPLICATION_ID);

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID,
                                     "flags", G_APPLICATION_NON_UNIQUE,
                                     nullptr));
}
