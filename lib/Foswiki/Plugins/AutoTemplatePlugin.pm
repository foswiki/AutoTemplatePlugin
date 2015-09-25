# Plugin for Foswiki
#
# Copyright (C) 2008 Oliver Krueger <oliver@wiki-one.net>
# Copyright (C) 2008-2015 Foswiki Contributors
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

our $VERSION = '5.00';
our $RELEASE = '25 Sep 2015';
our $SHORTDESCRIPTION = 'Automatically sets VIEW_TEMPLATE, EDIT_TEMPLATE and PRINT_TEMPLATE';
our $NO_PREFS_IN_TOPIC = 1;
our $debug;
our %knownTemplate = ();

sub initPlugin {
    my( $topic, $web, $user, $installWeb ) = @_;

    %knownTemplate = ();

    # get configuration
    my $override = $Foswiki::cfg{Plugins}{AutoTemplatePlugin}{Override} || 0;
    $debug = $Foswiki::cfg{Plugins}{AutoTemplatePlugin}{Debug} || 0;

    # is this an edit action?
    my $templateVar = _isEditAction()?'EDIT_TEMPLATE':_isPrintAction()?'PRINT_TEMPLATE':'VIEW_TEMPLATE';

    # back off if there is a view template already and we are not in override mode
    my $currentTemplate = Foswiki::Func::getPreferencesValue($templateVar);
    return 1 if $currentTemplate && !$override;

    # check if this is a new topic and - if so - try to derive the templateName from
    # the WebTopicEditTemplate
    # SMELL: templatetopic and formtemplate from url params come into play here as well
    if (!Foswiki::Func::topicExists($web, $topic)) {
      if (Foswiki::Func::topicExists($web, 'WebTopicEditTemplate')) {
        $topic = 'WebTopicEditTemplate';
      } else {
        return 1;
      }
    }

    # get it
    my $templateName = getTemplateName($web, $topic);

    # only set the view template if there is anything to set
    return 1 unless $templateName;

    # in edit mode, try to read the template to check if it exists
    if (_isEditAction() && !Foswiki::Func::readTemplate($templateName)) {
      writeDebug("edit tempalte not found");
      return 1;
    }

    # do it
    if ($debug) {
      if ( $currentTemplate ) {
        if ( $override ) {
          writeDebug("$templateVar already set, overriding with: $templateName");
        } else {
          writeDebug("$templateVar not changed/set");
        }
      } else {
        writeDebug("$templateVar set to: $templateName");
      }
    }
    $templateVar =~ s/^PRINT_/VIEW_/g; #sneak in VIEW again
    if ($Foswiki::Plugins::VERSION >= 2.1 ) {
      Foswiki::Func::setPreferencesValue($templateVar, $templateName);
    } else {
      $Foswiki::Plugins::SESSION->{prefs}->pushPreferenceValues( 'SESSION', { $templateVar => $templateName } );
    }

    # Plugin correctly initialized
    return 1;
}

sub getTemplateName {
    my ($web, $topic, $action) = @_;

    $action ||= _isEditAction()?'edit':_isPrintAction()?'print':'view';

    my $templateName = "";
    my $modeList = $Foswiki::cfg{Plugins}{AutoTemplatePlugin}{Mode} || "rules, exist";
    foreach my $mode (split(/\s*,\s*/, $modeList)) {
      if ( $mode eq "section" ) {
        $templateName = _getTemplateFromSectionInclude( $web, $topic, $action );
      } elsif ( $mode eq "exist" ) {
        $templateName = _getTemplateFromTemplateExistence( $web, $topic, $action );
      } elsif ( $mode eq "rules" ) {
        $templateName = _getTemplateFromRules( $web, $topic, $action );
      }
      last if $templateName;
    }

    # fall back to view for print template
    return getTemplateName($web, $topic, "view") if !defined($templateName) && $action eq 'print';

    return $templateName;
}

sub _getFormName {
    my ($web, $topic) = @_;

    my $request = Foswiki::Func::getCgiQuery();
    my $form = $request->param("formtemplate");
    return $form if defined $form && $form ne '';

    my ( $meta, $text ) = Foswiki::Func::readTopic( $web, $topic );

    $form = $meta->get("FORM") if $meta;
    $form = $form->{"name"} if $form;

    return $form;
}

sub _getTemplateFromSectionInclude {
    my ($web, $topic, $action) = @_;

    my $formName = _getFormName($web, $topic);
    return unless $formName;

    writeDebug("called _getTemplateFromSectionInclude($formName, $topic, $web)");

    my ($formweb, $formtopic) = Foswiki::Func::normalizeWebTopicName($web, $formName);

    # SMELL: This can be done much faster, if the formdefinition topic is read directly
    my $sectionName = $action."template";
    my $templateName = "%INCLUDE{ \"$formweb.$formtopic\" section=\"$sectionName\" warn=\"off\"}%";
    $templateName = Foswiki::Func::expandCommonVariables( $templateName, $topic, $web );

    return $templateName if _templateExists($templateName);

    return undef;
}

sub _isPrintAction {
    my $request = Foswiki::Func::getCgiQuery();
    my $contentType  = $request->param("contenttype") || '';
    my $cover  = $request->param("cover") || '';
    return $contentType eq 'application/pdf' || $cover =~ /print/ ? 1:0;
}

sub _isEditAction {
    return Foswiki::Func::getContext()->{edit}?1:0;
}

sub _templateExists {
    my $name = shift;

    return unless defined $name;

    unless (defined $knownTemplate{$name}) {
      my $text = Foswiki::Func::readTemplate($name);
      $knownTemplate{$name} = $text?1:0;
    }

    return $knownTemplate{$name};
}

# replaces Web.MyForm with Web.MyViewTemplate and returns Web.MyViewTemplate if it exists otherwise nothing
sub _getTemplateFromTemplateExistence {
    my ($web, $topic, $action) = @_;

    my $formName = _getFormName($web, $topic);
    return unless $formName;

    writeDebug("called _getTemplateFromTemplateExistence($formName, $topic, $web)");
    my ($templateWeb, $templateTopic) = Foswiki::Func::normalizeWebTopicName($web, $formName);

    $templateWeb =~ s/\//\./go;
    my $templateName = $templateWeb.'.'.$templateTopic;
    $templateName =~ s/Form$//;
    $templateName .= ucfirst($action);


    return $templateName if _templateExists($templateName);
    return undef;
}

sub _getTemplateFromRules {
    my ($web, $topic, $action) = @_;

    writeDebug("called _getTemplateFromRules($web, $topic)");

    # read template rules from preferences
    my $rules = Foswiki::Func::getPreferencesValue(uc($action."_TEMPLATE_RULES"));

    if ($rules) {
      $rules =~ s/^\s+//;
      $rules =~ s/\s+$//;

      # check full qualified topic name first
      foreach my $rule (split(/\s*,\s*/, $rules)) {
        if ($rule =~ /^(.*?)\s*=>\s*(.*?)$/) {
          my $pattern = $1;
          my $template = $2;
          return $template if "$web.$topic" =~ /^($pattern)$/ && _templateExists($template);
        }
      }
      # check topic name only
      foreach my $rule (split(/\s*,\s*/, $rules)) {
        if ($rule =~ /^(.*?)\s*=>\s*(.*?)$/) {
          my $pattern = $1;
          my $template = $2;
          return $template if $topic =~ /^($pattern)$/ && _templateExists($template);
        }
      }
    }

    # read template rules from config
    $rules = $Foswiki::cfg{Plugins}{AutoTemplatePlugin}{ucfirst($action).'TemplateRules'};

    if($rules) {
      # check full qualified topic name first
      foreach my $pattern (keys %$rules) {
        return $rules->{$pattern} if "$web.$topic" =~ /^($pattern)$/ && _templateExists($rules->{$pattern});
      }
      # check topic name only
      foreach my $pattern (keys %$rules) {
        return $rules->{$pattern} if $topic =~ /^($pattern)$/ && _templateExists($rules->{$pattern});
      }
    }

    return;
}

sub writeDebug {
    return unless $debug;
    #Foswiki::Func::writeDebug("- AutoTemplatePlugin - $_[0]");
    print STDERR "- AutoTemplatePlugin - $_[0]\n";
}

1;
