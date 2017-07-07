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

// This works partially, because of the issue with smooth edges
public class GalaPW.RoundedRectangleEffect : Clutter.Effect
{
	public float radius { get; construct; }

	public RoundedRectangleEffect (float radius)
	{
		Object (radius: radius);
	}

	public override void paint (Clutter.EffectPaintFlags flags)
	{
		Cogl.Path.round_rectangle (0, 0, actor.width, actor.height, radius, 0.05f);
		Cogl.clip_push_from_path ();
		actor.continue_paint ();
		Cogl.clip_pop ();
	}
}
