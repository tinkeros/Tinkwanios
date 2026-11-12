/* This converts $LK,"::/Demo/ToHtmlToTXTDemo/DemoInPage.DD"$ to
an plain ASCII text document named, "OutPage.DD".

*/

Cd(__DIR__);;
#include "ToTXT"

ToTXT("DemoInPage.DD.Z","~/DemoOutPage");
