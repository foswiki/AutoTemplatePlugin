# Copyright (C) 2008 Oliver Krueger <oliver@wiki-one.net>
# Copyright (C) 2008-2019 Foswiki Contributors
# All Rights Reserved.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# This piece of software is licensed under the GPLv2.

package Foswiki::Plugins::AutoTemplatePlugin::Core;

use strict;
use warnings;

use Foswiki::Func ();
use constant TRACE => 0;

sub new {
  my $class = shift;

  _writeDebug("called new");
  my $this = bless({
    override => $Foswiki::cfg{Plugins}{AutoTemplatePlugin}{Override} || 0,
    @_
  }, $class);

  $this->{templateExists} = {};
  $this->{metaCache} = {};
  $this->{templateCache} = {};

  return $this;
}

sub DESTROY {
  my $this = shift;

  undef $this->{templateExists};
  undef $this->{metaCache};
  undef $this->{templateCache};
}

sub setTemplateName {
  my ($this, $web, $topic) = @_;

  _writeDebug("called setTemplateName($web, $topic)");

  my $templateVar = _isEditAction() ? 'EDIT_TEMPLATE' : _isPrintAction() ? 'PRINT_TEMPLATE' : 'VIEW_TEMPLATE';

  # back off if there is a view template already and we are not in override mode
  my $currentTemplate = Foswiki::Func::getPreferencesValue($templateVar);
  return if $currentTemplate && !$this->{override};

  my $request = Foswiki::Func::getRequestObject();
  $currentTemplate = $request->param("template");
  return if $currentTemplate && !$this->{override};

  # check if this is a new topic and - if so - try to derive the templateName from
  # the WebTopicEditTemplate
  # SMELL: templatetopic and formtemplate from url params come into play here as well
  if (!Foswiki::Func::topicExists($web, $topic)) {
    if (Foswiki::Func::topicExists($web, 'WebTopicEditTemplate')) {
      $topic = 'WebTopicEditTemplate';
    } else {
      return;
    }
  }

  # get it
  my $templateName = $this->getTemplateName($web, $topic);

  # only set the view template if there is anything to set
  unless ($templateName) {
    _writeDebug("... no template");
    return;
  }

  # in edit mode, try to read the template to check if it exists
  if (_isEditAction() && !Foswiki::Func::readTemplate($templateName)) {
    _writeDebug("edit template not found");
    return;
  }

  # do it
  if (TRACE) {
    if ($currentTemplate) {
      if ($this->{override}) {
        _writeDebug("... $templateVar already set, overriding with: $templateName");
      } else {
        _writeDebug("... $templateVar not changed/set");
      }
    } else {
      _writeDebug("... $templateVar set to $templateName");
    }
  }

  $templateVar =~ s/^PRINT_/VIEW_/g;    #sneak in VIEW again

  if ($Foswiki::Plugins::VERSION >= 2.1) {
    Foswiki::Func::setPreferencesValue($templateVar, $templateName);
  } else {
    $Foswiki::Plugins::SESSION->{prefs}->pushPreferenceValues('SESSION', {$templateVar => $templateName});
  }
}

sub getTemplateName {
  my ($this, $web, $topic, $action) = @_;
  
  $action ||= _isEditAction() ? 'edit' : _isPrintAction() ? 'print' : 'view';

  _writeDebug("called getTemplateName($web, $topic, $action)");

  $web =~ s/\//./g;
  my $key = $web."::".$topic."::".$action;

  my $templateName = $this->{templateCache}{$key};
  if (defined $templateName) {
    _writeDebug("... found in cache");
    return $templateName;
  }

  my $modeList = $Foswiki::cfg{Plugins}{AutoTemplatePlugin}{Mode} || "rules, exist, type";
  #_writeDebug("modeList='$modeList'");

  foreach my $mode (split(/\s*,\s*/, $modeList)) {
    if ($mode eq "rules") {
      $templateName = $this->getTemplateFromRules($web, $topic, $action);
    } elsif ($mode eq "type") {
      $templateName = $this->getTemplateFromTopicType($web, $topic, $action);
    } elsif ($mode eq "exist") {
      $templateName = $this->getTemplateFromTemplateExistence($web, $topic, $action);
    } elsif ($mode eq "section") {
      $templateName = $this->getTemplateFromSectionInclude($web, $topic, $action);
    }
    last if $templateName;
  }

  # fall back to view for print template
  $templateName = $this->getTemplateName($web, $topic, "view") if !defined($templateName) && $action eq 'print';
  $this->{templateCache}{$key} = $templateName;

  return $templateName;
}

sub readTopic {
  my ($this, $web, $topic) = @_;

  $web =~ s/\//./g;

  my $key = $web."::".$topic;
  my $meta = $this->{metaCache}{$key};

  unless (defined $meta) {
    ($meta) = Foswiki::Func::readTopic($web, $topic);
    $this->{metaCache}{$key} = $meta;
  }

  return $meta;
}

sub getFormName {
  my ($this, $web, $topic, $meta) = @_;

  $meta = $this->readTopic($web, $topic) unless defined $meta;

  my $form;
  $form = $meta->get("FORM") if $meta;
  $form = $form->{"name"} if $form;
  $form ||= '';

  return $form;
}

sub getTopicType {
  my ($this, $web, $topic, $meta) = @_;

  $meta = $this->readTopic($web, $topic) unless defined $meta;

  my $topicType = $meta->get("FIELD", "TopicType");
  return unless $topicType;

  $topicType = $topicType->{value};
  $topicType =~ s/^\s+|\s+$//g;

  return split(/\s*,\s*/, $topicType);
}

sub getTemplateFromSectionInclude {
  my ($this, $web, $topic, $action) = @_;

  _writeDebug("called getTemplateFromSectionInclude($web, $topic, $action)");

  my $request = Foswiki::Func::getRequestObject();
  my $formName = $request->param("formtemplate");
  $formName = $this->getFormName($web, $topic) unless defined $formName && $formName ne '';
  return unless $formName;

  my ($formweb, $formtopic) = Foswiki::Func::normalizeWebTopicName($web, $formName);

  # SMELL: This can be done much faster, if the formdefinition topic is read directly
  my $sectionName = $action . "template";
  my $templateName = "%INCLUDE{ \"$formweb.$formtopic\" section=\"$sectionName\" warn=\"off\"}%";
  $templateName = Foswiki::Func::expandCommonVariables($templateName, $topic, $web);

  return unless $this->templateExists($templateName);
  return $templateName;
}

# get the most specific view for the given topic type
sub getTemplateFromTopicType {
  my ($this, $web, $topic, $action) = @_;

  _writeDebug("called getTemplateFromTopicType($web, $topic, $action)");

  my @topicType = $this->getTopicType($web, $topic);
  return unless @topicType;

  my $templateName;

  # is it a stub itself use existence
  if (grep { /\bTopicStub\b/ } @topicType) {
    $templateName = $this->getTemplateFromTemplateExistence($web, $topic, $action);
  }

  unless ($templateName) {
    foreach my $type (@topicType) {
      next unless Foswiki::Func::topicExists($web, $type);
      my $meta = $this->readTopic($web, $type);

      my $formName;
      if (grep { /\bTopicStub\b/ } $this->getTopicType($web, $type)) {
        my $target = $meta->get("FIELD", "Target");
        $formName = $target->{value} if $target;
      } else {
        $formName = $type;
      }

      $templateName = $this->getTemplateOfForm($web, $formName, $action);
      last if $this->templateExists($templateName);
      $templateName = undef;
    }
  }

  return $templateName;
}

# replaces Web.MyForm with Web.MyViewTemplate and returns Web.MyViewTemplate if it exists otherwise nothing
sub getTemplateFromTemplateExistence {
  my ($this, $web, $topic, $action) = @_;

  _writeDebug("called getTemplateFromTemplateExistence($web, $topic, $action)");

  my $request = Foswiki::Func::getRequestObject();
  my $formName = $request->param("formtemplate");
  $formName = $this->getFormName($web, $topic) unless defined $formName && $formName ne '';
  return unless $formName;

  my $templateName = $this->getTemplateOfForm($web, $formName, $action);

  return unless $this->templateExists($templateName);
  return $templateName;
}

sub getTemplateFromRules {
  my ($this, $web, $topic, $action) = @_;

  _writeDebug("called getTemplateFromRules($web, $topic, $action)");

  # read template rules from preferences
  my $rules = Foswiki::Func::getPreferencesValue(uc($action . "_TEMPLATE_RULES"));

  if ($rules) {
    $rules =~ s/^\s+//;
    $rules =~ s/\s+$//;

    # check full qualified topic name first
    foreach my $rule (split(/\s*,\s*/, $rules)) {
      if ($rule =~ /^(.*?)\s*=>\s*(.*?)$/) {
        my $pattern = $1;
        my $template = $2;
        return $template if "$web.$topic" =~ /^($pattern)$/ && $this->templateExists($template);
      }
    }
    # check topic name only
    foreach my $rule (split(/\s*,\s*/, $rules)) {
      if ($rule =~ /^(.*?)\s*=>\s*(.*?)$/) {
        my $pattern = $1;
        my $template = $2;
        return $template if $topic =~ /^($pattern)$/ && $this->templateExists($template);
      }
    }
  }

  # read template rules from config
  $rules = $Foswiki::cfg{Plugins}{AutoTemplatePlugin}{ucfirst($action) . 'TemplateRules'};

  if ($rules) {
    # check full qualified topic name first
    foreach my $pattern (keys %$rules) {
      return $rules->{$pattern} if "$web.$topic" =~ /^($pattern)$/ && $this->templateExists($rules->{$pattern});
    }
    # check topic name only
    foreach my $pattern (keys %$rules) {
      return $rules->{$pattern} if $topic =~ /^($pattern)$/ && $this->templateExists($rules->{$pattern});
    }
  }

  return;
}

sub templateExists {
  my ($this, $name) = @_;

  return unless defined $name;

  unless (defined $this->{templateExists}{$name}) {
    my $text = Foswiki::Func::readTemplate($name);
    $this->{templateExists}{$name} = (defined $text && $text ne "" ? 1 : 0);
  }

  return $this->{templateExists}{$name};
}

sub getTemplateOfForm {
  my ($this, $web, $formName, $action) = @_;

  my ($templateWeb, $templateTopic) = Foswiki::Func::normalizeWebTopicName($web, $formName);
  $templateWeb =~ s/\//\./g;

  my $templateName = $templateWeb . '.' . $templateTopic;
  $templateName =~ s/Form$//;
  $templateName .= ucfirst($action);

  return $templateName;
}

sub _isPrintAction {
  my $request = Foswiki::Func::getRequestObject();
  my $contentType = $request->param("contenttype") || '';
  my $cover = $request->param("cover") || '';
  return $contentType eq 'application/pdf' || $cover =~ /print/ ? 1 : 0;
}

sub _isEditAction {
  return Foswiki::Func::getContext()->{edit} ? 1 : 0;
}


sub _writeDebug {
  return unless TRACE;
  print STDERR "- AutoTemplatePlugin - $_[0]\n";
}

1;
