#!/bin/sh

#
# Part of as2api - http://www.badgers-in-foil.co.uk/projects/as2api/
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#

ruby=ruby
rcov=/home/dave/opt/bin/rcov

testdir=$(dirname $0)
lib=$testdir/../lib

if [ "$1" == "cover" ]; then
  rb="$rcov --exclude-only=/usr/lib"
else
  rb="$ruby -w"
fi

$rb -I $lib -I $testdir $testdir/ts.rb
