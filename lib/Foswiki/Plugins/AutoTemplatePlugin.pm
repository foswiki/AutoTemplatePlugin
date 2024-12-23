# Copyright (C) 2008 Oliver Krueger <oliver@wiki-one.net>
# Copyright (C) 2008-2024 Foswiki Contributors
# All Rights Reserved.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# This piece of software is licensed under the GPLv2.

package Foswiki::Plugins::AutoTemplatePlugin;

use strict;
use warnings;

use Foswiki::Func();
use Foswiki::Plugins::AutoTemplatePlugin::Core();

our $VERSION = '7.11';
our $RELEASE = '%$RELEASE%';
our $SHORTDESCRIPTION = 'Automatically sets VIEW_TEMPLATE, EDIT_TEMPLATE and PRINT_TEMPLATE';
our $LICENSECODE = '%$LICENSECODE%';
our $NO_PREFS_IN_TOPIC = 1;
our $core;

sub initPlugin {
  my ($topic, $web) = @_;

  getCore()->setTemplateName($web, $topic);

  return 1;
}

sub getTemplateName {
  my ($web, $topic, $action) = @_;

  return getCore()->getTemplateName($web, $topic, $action);
} 

sub getCore {
  $core //= Foswiki::Plugins::AutoTemplatePlugin::Core->new();
  return $core;
}

sub finishPlugin {
  $core->finish() if defined $core;
  undef $core;
}

1;
