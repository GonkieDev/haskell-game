{-# LANGUAGE ScopedTypeVariables #-}
module Main(main) where

import Control.Monad (when, void)
import Control.Exception (SomeException, bracket, try)
import Foreign.Ptr (nullPtr)
import System.Win32.DLL (getModuleHandle)
import qualified Graphics.Win32

main :: IO ()
main =
  Graphics.Win32.allocaPAINTSTRUCT $ \ lpps -> do
  hwnd <- createWindow 200 200 (wndProc lpps onPaint)
  messagePump hwnd

onPaint :: Graphics.Win32.RECT -> Graphics.Win32.HDC -> IO ()
onPaint (_,_,w,h) hdc = do
   Graphics.Win32.setBkMode hdc Graphics.Win32.tRANSPARENT
   Graphics.Win32.setTextColor hdc (Graphics.Win32.rgb 255 255 255)
   let y | h==10     = 0
         | otherwise = ((h-10) `div` 2)
       x | w==50     = 0
         | otherwise = (w-50) `div` 2
   Graphics.Win32.textOut hdc x y "haskell-game wow"
   return ()

wndProc :: Graphics.Win32.LPPAINTSTRUCT
        -> (Graphics.Win32.RECT -> Graphics.Win32.HDC -> IO ())
        -> Graphics.Win32.HWND
        -> Graphics.Win32.WindowMessage
        -> Graphics.Win32.WPARAM
        -> Graphics.Win32.LPARAM
        -> IO Graphics.Win32.LRESULT
wndProc lpps onPaint hwnd wmsg wParam lParam
 | wmsg == Graphics.Win32.wM_DESTROY = do
     Graphics.Win32.sendMessage hwnd Graphics.Win32.wM_QUIT 1 0
     return 0
 | wmsg == Graphics.Win32.wM_PAINT && hwnd /= nullPtr = do
     r <- Graphics.Win32.getClientRect hwnd
     paintWith lpps hwnd (onPaint r)
     return 0
 | otherwise =
     Graphics.Win32.defWindowProcSafe (Just hwnd) wmsg wParam lParam

createWindow :: Int -> Int -> Graphics.Win32.WindowClosure -> IO Graphics.Win32.HWND
createWindow width height wndProc = do
  let winClass = Graphics.Win32.mkClassName "HaskellGameWC"
  icon         <- Graphics.Win32.loadIcon   Nothing Graphics.Win32.iDI_APPLICATION
  cursor       <- Graphics.Win32.loadCursor Nothing Graphics.Win32.iDC_ARROW
  bgBrush      <- Graphics.Win32.createSolidBrush (Graphics.Win32.rgb 123 123 123)
  mainInstance <- getModuleHandle Nothing
  Graphics.Win32.registerClass
          ( Graphics.Win32.cS_VREDRAW + Graphics.Win32.cS_HREDRAW
          , mainInstance
          , Just icon
          , Just cursor
          , Just bgBrush
          , Nothing
          , winClass
          )
  w <- Graphics.Win32.createWindow
                 winClass
                 "Haskell Game"
                 Graphics.Win32.wS_OVERLAPPEDWINDOW
                 Nothing Nothing -- leave it to the shell to decide the position
                                 -- at where to put the window initially
                 (Just width)
                 (Just height)
                 Nothing      -- no parent, i.e, root window is the parent.
                 Nothing      -- no menu handle
                 mainInstance
                 wndProc
  Graphics.Win32.showWindow w Graphics.Win32.sW_SHOWNORMAL
  Graphics.Win32.updateWindow w
  return w

messagePump :: Graphics.Win32.HWND -> IO ()
messagePump hwnd = Graphics.Win32.allocaMessage $ \msg ->
  let pump = do
       r :: Either SomeException Bool
         <- Control.Exception.try $ Graphics.Win32.getMessage msg (Just hwnd)
       when (either (const False) id r) $ do
          () <$ Graphics.Win32.translateMessage msg
          () <$ Graphics.Win32.dispatchMessage msg
          pump
  in pump

paintWith :: Graphics.Win32.LPPAINTSTRUCT -> Graphics.Win32.HWND -> (Graphics.Win32.HDC -> IO a) -> IO a
paintWith lpps hwnd p =
  bracket
    (Graphics.Win32.beginPaint hwnd lpps)
    (const $ Graphics.Win32.endPaint hwnd lpps)
    p


