import XMonad
import XMonad.Hooks.EwmhDesktops (ewmh)
import XMonad.Hooks.FadeInactive
import XMonad.Actions.CopyWindow
import XMonad.Config.Desktop (desktopLayoutModifiers)
-- import XMonad.Config.Gnome
import XMonad.Config.Kde
import XMonad.Layout
import XMonad.Layout.NoBorders (lessBorders, Ambiguity(Screen))
import XMonad.Layout.PerWorkspace
import XMonad.Layout.IM
import XMonad.Layout.Grid
import qualified XMonad.StackSet as S
import Control.Monad
import Data.Ratio ((%))

-- myLayout = modWorkspace "1" (withIM (1%7) (And (ClassName "Pidgin") (Role "buddy_list")

myLayout = modWorkspace "1" (withIM (1%7) (And (ClassName "Pidgin") (Role "buddy_list"))) $
           modWorkspace "9" (withIM (1%7) (And (ClassName "Steam") (Title "Friends"))) $         
           Grid ||| tiled ||| Full
    where
        tiled   = Tall nmaster delta ratio

        -- The default number of windows in the master pane
        nmaster = 1

        -- Default proportion of screen occupied by master pane
        ratio   = 1/2

        -- Percent of screen to increment by when resizing panes
        delta   = 3/100


myManager = composeAll
--    [ isEmpathy --> moveToIM
    [ ( className =? "Pidgin" ) --> doShift "1"
    , ( className =? "Steam" ) --> doShift "9"
    , ( resource =? "plasma-desktop" ) --> doFloat
    ]
  where
    role = stringProperty "WM_WINDOW_ROLE"
--    isEmpathy = className =? "Empathy" <||> role =? "chat"
--    moveToIM = doF(copy "1")
--    moveToIM = doF $ S.shift "1"
--    viewShift = doF . liftM2 (.) S.greedyView S.shift

myLogHook :: X ()
myLogHook = fadeInactiveLogHook fadeAmount
    where fadeAmount = 0.8

main = xmonad $ emwh $ kdeConfig
    {   focusedBorderColor  = "#006600" 
    ,   normalBorderColor   = "#FFFFFF" 
    ,   layoutHook          = lessBorders Screen $ desktopLayoutModifiers(myLayout)
    ,   manageHook          = myManager <+> manageHook kdeConfig
    ,   terminal            = "terminator"
    ,   logHook             = myLogHook
    }
