/*-
 * Copyright (c) 2017 Adam Bieńkowski
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 2.1 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 *
 * Authored by: Adam Bieńkowski <donadigos159@gmail.com>
 */

public class GalaPW.PopupWindow : Clutter.Actor {
    private const int BUTTON_SIZE = 36;
    private const int CONTAINER_MARGIN = BUTTON_SIZE / 2;
    private const int SHADOW_SIZE = 100;
    private const uint FADE_OUT_TIMEOUT = 200;
    private const float MINIMUM_SCALE = 0.1f;
    private const float MAXIMUM_SCALE = 1.0f;
    private const int SCREEN_MARGIN = 0;

    public signal void closed ();

    public Meta.WindowActor window_actor { get; construct; }
    public Clutter.Rect? container_clip { get; construct; }
    public int screen_width { get; construct; }
    public int screen_height { get; construct; }

    private static Clutter.Image? resize_image;

    private Clutter.Actor clone;
    private Clutter.Actor container;
    private Clutter.Actor close_button;
    private Clutter.Actor resize_button;
    private Clutter.Actor resize_handle;
    private Clutter.ClickAction close_action;
    private Clutter.DragAction resize_action;
    private MoveAction move_action;

    private bool dragging = false;
    private bool clicked = false;

    private int x_offset_press = 0;
    private int y_offset_press = 0;

    private float begin_resize_width = 0.0f;
    private float begin_resize_height = 0.0f;

    construct {
        reactive = true;

        set_pivot_point (0.5f, 0.5f);

        var window = window_actor.get_meta_window ();
        window.unmanaged.connect (on_close_click_clicked);

        clone = new Clutter.Clone (window_actor.get_texture ());

        container = new Clutter.Actor ();
        container.reactive = true;
        container.set_scale (0.35f, 0.35f);
        container.clip_rect = container_clip;
        container.add_effect (new Gala.ShadowEffect (SHADOW_SIZE, 2));
        container.add_child (clone);

        if (container_clip == null) {
            window_actor.notify["allocation"].connect (on_allocation_changed);
            container.set_position (CONTAINER_MARGIN, CONTAINER_MARGIN);
        }

        update_size ();
        update_container_position ();

        close_action = new Clutter.ClickAction ();
        close_action.clicked.connect (on_close_click_clicked);

        close_button = Gala.Utils.create_close_button ();
        close_button.set_size (BUTTON_SIZE, BUTTON_SIZE);
        close_button.opacity = 0;
        close_button.reactive = true;
        close_button.set_easing_duration (300);
        close_button.add_action (close_action);

        resize_action = new Clutter.DragAction ();
        resize_action.drag_begin.connect (on_resize_drag_begin);
        resize_action.drag_end.connect (on_resize_drag_end);
        resize_action.drag_motion.connect (on_resize_drag_motion);

        resize_handle = new Clutter.Actor ();
        resize_handle.set_size (BUTTON_SIZE, BUTTON_SIZE);
        resize_handle.set_pivot_point (0.5f, 0.5f);
        resize_handle.set_position (width - BUTTON_SIZE, height - BUTTON_SIZE);
        resize_handle.reactive = true;
        resize_handle.add_action (resize_action);

        resize_button = new Clutter.Actor ();
        resize_button.set_pivot_point (0.5f, 0.5f);
        resize_button.set_size (BUTTON_SIZE, BUTTON_SIZE);
        resize_button.set_position (width - BUTTON_SIZE, height - BUTTON_SIZE);
        resize_button.opacity = 0;
        resize_button.reactive = true;
        resize_button.content = get_resize_image ();

        add_child (container);
        add_child (close_button);
        add_child (resize_button);
        add_child (resize_handle);

        move_action = new MoveAction ();
        move_action.drag_begin.connect (() => on_move_begin ());
        move_action.drag_end.connect (() => on_move_end ());
        move_action.move.connect (on_move);
        container.add_action (move_action);

        set_position (SCREEN_MARGIN, screen_height - SCREEN_MARGIN - height);
    }

    // From https://opensourcehacker.com/2011/12/01/calculate-aspect-ratio-conserving-resize-for-images-in-javascript/
    private static void calculate_aspect_ratio_size_fit (float src_width, float src_height,
                                                        float max_width, float max_height,
                                                        out float width, out float height) {
        float ratio = float.min (max_width / src_width, max_height / src_height);
        width = src_width * ratio;
        height = src_height * ratio;
    }

    private static Clutter.Image? get_resize_image () {
        if (resize_image == null) {
            try {
                string filename = Path.build_filename (Config.PLUGIN_DATA_DIR, "resize.svg");
                var pixbuf = new Gdk.Pixbuf.from_file (filename);

                resize_image = new Clutter.Image ();
                resize_image.set_data (pixbuf.get_pixels (),
                                Cogl.PixelFormat.RGBA_8888,
                                pixbuf.get_width (),
                                pixbuf.get_height (),
                                pixbuf.get_rowstride ());
            } catch (Error e) {
                warning (e.message);
            }
        }

        return resize_image;
    }

    private static void get_current_cursor_position (out int x, out int y) {
        Gdk.Display.get_default ().get_device_manager ().get_client_pointer ().get_position (null, out x, out y);
    }

    public PopupWindow (Meta.WindowActor window_actor,
                        Clutter.Rect? container_clip,
                        int screen_width,
                        int screen_height) {
        Object (
            window_actor: window_actor,
            container_clip: container_clip,
            screen_width: screen_width,
            screen_height: screen_height
        );
    }

    public override bool enter_event (Clutter.CrossingEvent event) {
        close_button.opacity = 255;

        resize_button.set_easing_duration (300);
        resize_button.opacity = 255;
        resize_button.set_easing_duration (0);
        return true;
    }

    public override bool leave_event (Clutter.CrossingEvent event) {
        close_button.opacity = 0;

        resize_button.set_easing_duration (300);
        resize_button.opacity = 0;
        resize_button.set_easing_duration (0);
        return true;
    }

    private void on_move_begin () {
        var manager = Gdk.Display.get_default ().get_device_manager ();
        var pointer = manager.get_client_pointer ();

        int px, py;
        pointer.get_position (null, out px, out py);

        x_offset_press = (int)(px - x);
        y_offset_press = (int)(py - y);

        clicked = true;
        dragging = false;
    }

    private void on_move_end () {
        clicked = false;

        if (dragging) {
            update_screen_position ();
            dragging = false;
        } else {
            activate ();
        }
    }

    private void on_move () {
        if (!clicked) {
            return;
        }

        float motion_x, motion_y;
        move_action.get_motion_coords (out motion_x, out motion_y);

        x = (int)motion_x - x_offset_press;
        y = (int)motion_y - y_offset_press;

        if (!dragging) {
            dragging = true;
        }
    }

    private void on_resize_drag_begin (Clutter.Actor actor, float event_x, float event_y, Clutter.ModifierType type) {
        begin_resize_width = width;
        begin_resize_height = height;
    }

    private void on_resize_drag_end (Clutter.Actor actor, float event_x, float event_y, Clutter.ModifierType type) {
        reposition_resize_handle ();
    }

    private void on_resize_drag_motion (Clutter.Actor actor, float delta_x, float delta_y) {
        float press_x, press_y;
        resize_action.get_press_coords (out press_x, out press_y);

        int motion_x, motion_y;
        get_current_cursor_position (out motion_x, out motion_y);

        float diff_x = motion_x - press_x;
        float diff_y = motion_y - press_y;

        width = begin_resize_width + diff_x;
        height = begin_resize_height + diff_y;

        update_container_scale ();
        update_size ();
        reposition_resize_button ();
    }

    private void on_allocation_changed () {
        update_size ();
        reposition_resize_button ();
        reposition_resize_handle ();
    }

    private void on_close_click_clicked () {
        set_easing_duration (FADE_OUT_TIMEOUT);
        set_easing_mode (Clutter.AnimationMode.EASE_IN_QUAD);

        opacity = 0;

        Clutter.Threads.Timeout.add (FADE_OUT_TIMEOUT, () => {
            closed ();
            return false;
        });
    }

    private void update_size () {
        if (container_clip != null) {
            width = (int)(container_clip.get_width () * container.scale_x + BUTTON_SIZE);
            height = (int)(container_clip.get_height () * container.scale_y + BUTTON_SIZE);
        } else {
            width = (int)(container.width * container.scale_x + BUTTON_SIZE);
            height = (int)(container.height * container.scale_y + BUTTON_SIZE);
        }
    }

    private void update_container_scale () {
        float src_width;
        float src_height;
        if (container_clip != null) {
            src_width = container_clip.get_width ();
            src_height = container_clip.get_height ();
        } else {
            src_width = container.width;
            src_height = container.height;
        }

        float max_width = width - BUTTON_SIZE;
        float max_height = height - BUTTON_SIZE;

        float new_width, new_height;
        calculate_aspect_ratio_size_fit (
            src_width, src_height,
            max_width, max_height,
            out new_width, out new_height
        );

        float window_width, window_height;
        get_target_window_size (out window_width, out window_height);

        float new_scale_x = new_width / window_width;
        float new_scale_y = new_height / window_height;

        container.scale_x = new_scale_x.clamp (MINIMUM_SCALE, MAXIMUM_SCALE);
        container.scale_y = new_scale_y.clamp (MINIMUM_SCALE, MAXIMUM_SCALE);

        update_container_position ();
    }

    private void update_container_position () {
        if (container_clip != null) {
            container.x = (float)(-container_clip.get_x () * container.scale_x + CONTAINER_MARGIN);
            container.y = (float)(-container_clip.get_y () * container.scale_y + CONTAINER_MARGIN);
        }
    }

    private void update_screen_position () {
        set_easing_duration (300);

        if (x <= SCREEN_MARGIN) {
            x = SCREEN_MARGIN;
        } else if (x + width >= screen_width - SCREEN_MARGIN) {
            x = screen_width - SCREEN_MARGIN - width;
        }

        if (y <= SCREEN_MARGIN) {
            y = SCREEN_MARGIN;
        } else if (y + height >= screen_height - SCREEN_MARGIN) {
            y = screen_height - SCREEN_MARGIN - height;
        }

        set_easing_duration (0);
    }

    private void reposition_resize_button () {
        resize_button.set_position (width - BUTTON_SIZE, height - BUTTON_SIZE);
    }

    private void reposition_resize_handle () {
        resize_handle.set_position (width - BUTTON_SIZE, height - BUTTON_SIZE);
    }

    private void get_target_window_size (out float width, out float height) {
        if (container_clip != null) {
            width = container_clip.get_width ();
            height = container_clip.get_height ();
        } else {
            width = window_actor.width;
            height = window_actor.height;
        }
    }

    private void activate () {
        var window = window_actor.get_meta_window ();
        window.activate (Clutter.get_current_event_time ());
    }
}