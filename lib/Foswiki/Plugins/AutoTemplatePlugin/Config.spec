# ---+ Extensions
# ---++ AutoTemplatePlugin
# This is the configuration used by the <b>AutoTemplatePlugin</b>.

# **BOOLEAN LABEL="Debug"**
# Turn on/off debugging in debug.txt
$Foswiki::cfg{Plugins}{AutoTemplatePlugin}{Debug} = 0;

# **BOOLEAN LABEL="Override"**
# Template defined by form overrides existing VIEW_TEMPLATE or EDIT_TEMPLATE settings
$Foswiki::cfg{Plugins}{AutoTemplatePlugin}{Override} = 0;

# **STRING LABEL="Mode"**
# Comma separated list of modes defining how to find the view or edit template. 
# The following modes can be combined:
# <ul>
# <li> 'exist': the template name is derived from the name of the form definition topic. </li>
# <li> 'section': the template name is defined in a section in the form definition topic. </li>
# <li> 'rules': the template name is defined using the below rule sets in <code>ViewTemplateRules</code>
#      and <code>EditTemplateRules</code> </li>
# <li> 'type': derive the template from the !TopicType formfield
# </ul>
$Foswiki::cfg{Plugins}{AutoTemplatePlugin}{Mode} = 'rules, exist, type';

# **PERL LABEL="ViewTemplate Rules" CHECK="undefok emptyok"**
# Rules to derive the view template name. This is a list of rules of the form
# <code>'pattern' => 'template'</code>. The current topic is matched against each of the
# patterns in the given order. The first matching pattern determines the concrete view template.
$Foswiki::cfg{Plugins}{AutoTemplatePlugin}{ViewTemplateRules} = {
  'ChangePassword' => 'ChangePasswordView',
  'ResetPassword' => 'ResetPasswordView',
  'ChangeEmailAddress' => 'ChangeEmailAddressView',
  'UserRegistration' => 'UserRegistrationView',
  'WebAtom' => 'WebAtomView',
  'WebChanges' => 'WebChangesView',
  'SiteChanges' => 'SiteChangesView',
  'WebCreateNewTopic' => 'WebCreateNewTopicView',
  'WebRss' => 'WebRssView',
  'WebSearchAdvanced' => 'WebSearchAdvancedView',
  'WebSearch' => 'WebSearchView',
  'WebTopicList' => 'WebTopicListView',
  'WebIndex' => 'WebIndexView',
  'WikiGroups' => 'WikiGroupsView',
  'WikiUsers' => 'WikiUsersView',
};

# **PERL LABEL="EditTemplate Rules" CHECK="undefok emptyok"**
# Rules to derive the edit template name. The format is the same as for the <code>{ViewTempalteRules}</code>
# configuration. This rule set is used during edit.
$Foswiki::cfg{Plugins}{AutoTemplatePlugin}{EditTemplateRules} = { };

# **PERL LABEL="PrintTemplate Rules" CHECK="undefok emptyok"**
# Rules to set the print template when exporting PDF or the like. The format is the same as for the <code>{ViewTempalteRules}</code>
# configuration. 
$Foswiki::cfg{Plugins}{AutoTemplatePlugin}{PrintTemplateRules} = { };

1;
