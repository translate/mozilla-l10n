==============
Firefox Phases
==============
The following are guidelines for how we classify the various components of Firefox.
We call them phases, or goals.  The aim is to get you focused on the most important
parts of Firefox.  We aim to get you translating user facing strings before anything
else.  We also leave a bunch of strings to the end and classify a number that
you can safely ignore.  Following the phases you might never get a 100% translated
Firefox.  When you are done this phases help direct your focus, put your energy
into new strings that your user will actually see.

Phases
======
The following are to be completed in the order that we list below.  We give the phase name
as well as a description of what might appear in that phase.

Must Translate
--------------
These are phases that we must complete to be included in a Firefox release. When translating
new strings follow this order. Also when reviewing checks you can use this order so that you
focus on the most important translations first.

+--------+----------------------------------------------------------------------------------------+
| Phase  | Details                                                                                |
+========+========================================================================================+
| shared | Shared between Desktop Firefox and Firefox Mobile.                                     |
+--------+----------------------------------------------------------------------------------------+
| user1  | Anything that appears when first starting, using menus or browsing the web in normal   |
|        | use e.g. File, Edit, View menus; Find bar at bottom, error pages, first run dialogues  |
|        | (Moving from secure to insecure pages, browsing offline, etc), About page, Rights      |
|        | notification. Excluded: some configuration menus that are too complicated, e.g.        |
|        | character set selection                                                                |
|        | * One entry needed from ext ext/rep/ch/report* that appears in the help menu           |
|        | "Report Broken Web Sites"                                                              |
|        | Translation related feature.                                                           |
+--------+----------------------------------------------------------------------------------------+
| lang   | Only do the most important languages (also read regions)                               |
|        | i.e. your language and languages commonly refered to                                   |
|        | or used by your users.  *DO NOT* translate everything!                                 |
+--------+----------------------------------------------------------------------------------------+
| user2  | Extensions/addons, Download manager, Bookmarks, Places, File browsing/downloading,     |
|        | Private Browsing, Session Restore, Sync, Video, PDF viewer, Health report, Crash       |
|        | reporter                                                                               |
+--------+----------------------------------------------------------------------------------------+
| user3  | Still focused on use: print dialogue, other XXX... menus accesible, Tab Groups         |
|        | WebRTC related features.                                                               |
+--------+----------------------------------------------------------------------------------------+
| config1| First layer of Preference dialog is translated including dropdowns                     |
+--------+----------------------------------------------------------------------------------------+
| user4  | Page info, page source, page properties, report broken websites, dom inspector,        |
|        | about:rights page, about:permissions, profile reset, WebApps                           |
+--------+----------------------------------------------------------------------------------------+
| config2| All XXXX... are translated, e.g. Cookies, charset names, Advanced settings             |
+--------+----------------------------------------------------------------------------------------+
| install| Anything related to installation.  Not critical as mostly people use language packs    |
|        | but allows a team to focus on installation when needed. Also include migration         |
+--------+----------------------------------------------------------------------------------------+
|platform| platform specific configuration                                                        |
+--------+----------------------------------------------------------------------------------------+
| other,1| Everything not yet classified                                                          |
+--------+----------------------------------------------------------------------------------------+

Optional
--------
These you can do if you are targetting the specific audience mentioned.

+------------+------------------------------------------------------------------------------------+
| Phase      | Details                                                                            |
+============+====================================================================================+
| developers | All web developer centric parts of Firefox.  If web developers who speak your      |
|            | language mostly work in English then rather leave this untranslated.               |
+------------+------------------------------------------------------------------------------------+

Safely Ignore
-------------
You can safely ignore any strings that appear in these phases.

+----------+------------------------------------------------------------------------------------+
| Phase    | Details                                                                            |
+==========+====================================================================================+
| security | Certificate lists, etc.  Since most of this is not understood by anyone in English |
|          | and most users will never see it rather leave it untranslated.  If someone does    |
|          | see something here like an error it will make more sense to see it in English      |
|          | so that they can search the Internet for the error.                                |
+----------+------------------------------------------------------------------------------------+
| notnb    | Not important stuff that you can safely leave right till the end.  These are things|
|          | like jokes and pages that nobody will ever see.  Rather focus on areas that impact |
|          | your users.                                                                        |
+----------+------------------------------------------------------------------------------------+
| never    | Things that we will never translate.  Examples of things that you will see here are|
|          | XML error messages.  Since these are only translated into French, German and some  |
|          | other languages for the XML spec leave them untranslated.                          |
+----------+------------------------------------------------------------------------------------+
