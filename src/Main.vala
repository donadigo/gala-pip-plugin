//
//  Copyright (C) 2017 Adam Bieńkowski
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

public class GalaPW.Plugin : Gala.Plugin
{
	private Gee.ArrayList<PopupWindow> windows;

	private Gala.WindowManager? wm = null;
	private SelectionArea? selection_area;

	construct {
		windows = new Gee.ArrayList<PopupWindow> ();
	}

	public override void initialize (Gala.WindowManager wm)
	{
		this.wm = wm;

		var screen = wm.get_screen ();
		var display = screen.get_display ();

		var settings = new Settings ("org.pantheon.desktop.gala.plugins.popup-window");
		display.add_keybinding ("key", settings, Meta.KeyBindingFlags.NONE, key_handler_func);
	}

	public override void destroy ()
	{
		clear_selection_area ();

		foreach (var popup_window in windows) {
			untrack_window (popup_window);
		}

		windows.clear ();
	}

	private void key_handler_func (Meta.Display display, Meta.Screen screen, Meta.Window? window, Clutter.KeyEvent? event, Meta.KeyBinding binding)
	{
		show_selection_area ();
	}

	private void show_selection_area ()
	{
		var screen = wm.get_screen ();
		var rect = screen.get_monitor_geometry (screen.get_primary_monitor ());

		selection_area = new SelectionArea (wm);
		selection_area.set_size (rect.width, rect.height);
		selection_area.set_position (rect.x, rect.y);
		selection_area.selected.connect (on_selection_actor_selected);
		selection_area.captured.connect (on_selection_actor_captured);
		selection_area.closed.connect (clear_selection_area);

		track_actor (selection_area);
		wm.ui_group.add_child (selection_area);

		selection_area.start_selection ();
	}

	private void on_selection_actor_selected (float x, float y)
	{
		clear_selection_area ();

		var screen = wm.get_screen ();

		int screen_width, screen_height;
		screen.get_size (out screen_width, out screen_height);

		var selected = get_window_actor_at (x, y);
		if (selected != null) {
			var popup_window = new PopupWindow (selected, null, screen_width, screen_height);
			add_window (popup_window);
		}
	}

	private void on_selection_actor_captured (int x, int y, int width, int height)
	{
		clear_selection_area ();

		var screen = wm.get_screen ();

		int screen_width, screen_height;
		screen.get_size (out screen_width, out screen_height);

		var active = get_active_window_actor ();
		if (active != null) {
			int point_x = x - (int)active.x;
			int point_y = y - (int)active.y;

			var rect = Clutter.Rect.alloc ();
			var clip = rect.init (point_x, point_y, width, height);

			var popup_window = new PopupWindow (active, clip, screen_width, screen_height);
			add_window (popup_window);
		}
	}

	private void clear_selection_area ()
	{
		if (selection_area != null) {
			untrack_actor (selection_area);
			update_region ();

			selection_area.destroy ();
		}
	}

	private Meta.WindowActor? get_window_actor_at (float x, float y)
	{
		var screen = wm.get_screen ();
		unowned List<weak Meta.WindowActor> actors = Meta.Compositor.get_window_actors (screen);

		var copy = actors.copy ();
		copy.reverse ();

		weak Meta.WindowActor? selected = null;
		copy.@foreach ((actor) => {
			if (selected != null) {
				return;
			}

			var window = actor.get_meta_window ();
			var bbox = actor.get_allocation_box ();
			if (!window.is_hidden () && bbox.contains (x, y)) {
				selected = actor;
			}
		});

		return selected;
	}

	private Meta.WindowActor? get_active_window_actor ()
	{
		var screen = wm.get_screen ();
		unowned List<weak Meta.WindowActor> actors = Meta.Compositor.get_window_actors (screen);

		var copy = actors.copy ();
		copy.reverse ();

		weak Meta.WindowActor? active = null;
		actors.@foreach ((actor) => {
			if (active != null) {
				return;
			}

			var window = actor.get_meta_window ();
			if (window.has_focus ()) {
				active = actor;
			}
		});

		return active;
	}

	private void add_window (PopupWindow popup_window)
	{
		popup_window.closed.connect (() => remove_window (popup_window));
		windows.add (popup_window);
		track_actor (popup_window);
		wm.ui_group.add_child (popup_window);
	}

	private void remove_window (PopupWindow popup_window)
	{
		windows.remove (popup_window);
		untrack_window (popup_window);
	}

	private void untrack_window (PopupWindow popup_window)
	{
		untrack_actor (popup_window);
		update_region ();
		popup_window.destroy ();
	}
}

public Gala.PluginInfo register_plugin ()
{
	return Gala.PluginInfo () {
		name = "Popup Window",
		author = "Adam Bieńkowski <donadigos159@gmail.com>",
		plugin_type = typeof (GalaPW.Plugin),
		provides = Gala.PluginFunction.ADDITION,
		load_priority = Gala.LoadPriority.IMMEDIATE
	};
}
