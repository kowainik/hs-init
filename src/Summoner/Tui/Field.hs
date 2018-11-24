{-# LANGUAGE Rank2Types #-}

{- | This modules adds necessary functions for Forms and Form fields
that are not covered in @brick@ library.
-}

module Summoner.Tui.Field
       ( strField
       , checkboxField
       , activeCheckboxField
       , radioField
       , disabledAttr
       ) where

import Brick (BrickEvent (..), EventM, Location (..), Widget, clickable, showCursor, str, vBox,
              withAttr, withDefAttr, (<+>))
import Brick.AttrMap (AttrName)
import Brick.Forms (FormField (..), FormFieldState (..), checkboxCustomField, focusedFormInputAttr,
                    radioCustomField)
import Lens.Micro (Lens', lens, (^.))

strField :: forall s e n . String -> s -> FormFieldState s e n
strField t _ = FormFieldState
    { formFieldState = ()
    , formFieldLens = fakeLens
    , formFields = []
    , formFieldRenderHelper = renderString
    , formFieldConcat = vBox
    }
  where
    -- looool
    fakeLens :: Lens' s ()
    fakeLens = lens (const ()) (\s () -> s)

    renderString :: Widget n -> Widget n
    renderString w = str t <+> w

{- | Custom checkbox with unique fancy style.
-}
checkboxField
    :: (Ord n, Show n)
    => Lens' s Bool -- ^ The state lens for this value.
    -> n            -- ^ The resource name for the input field.
    -> Text         -- ^ The label for the check box, to appear at its right.
    -> s            -- ^ The initial form state.
    -> FormFieldState s e n
checkboxField = checkboxCustomField '⟬' '✔' '⟭'

{- | Custom radio button with unique fancy style.
-}
radioField
    :: (Ord n, Show n, Eq a)
    => Lens' s a       -- ^ The state lens for this value.
    -> [(a, n, Text)]  -- ^ The available choices, in order.
    -> s               -- ^ The initial form state.
    -> FormFieldState s e n
radioField = radioCustomField '❮' '◆' '❯'

-- | Checkbox that can be disabled.
activeCheckboxField
    :: forall n s e . Ord n
    => Lens' s Bool
    -> Bool    -- ^ False if checkbox is disabled
    -> n
    -> String  -- ^ The label for the check box, to appear at its right.
    -> s       -- ^ The initial form state.
    -> FormFieldState s e n
activeCheckboxField stLens isEnabled name label initialState = FormFieldState
    { formFieldState        = initVal
    , formFields            = [checkboxFormField]
    , formFieldLens         = stLens
    , formFieldRenderHelper = id
    , formFieldConcat       = vBox
    }
  where
    initVal :: Bool
    initVal = initialState ^. stLens

    handleEvent :: BrickEvent n e -> Bool -> EventM n Bool
    handleEvent (MouseDown n _ _ _) s
        | isEnabled && n == name = pure $ not s
    handleEvent _ s = pure s

    checkboxFormField :: FormField Bool Bool e n
    checkboxFormField = FormField
        { formFieldName = name
        , formFieldValidate = Just
        , formFieldExternallyValid = True
        , formFieldRender = renderCheckbox isEnabled label name
        , formFieldHandleEvent = handleEvent
        }

renderCheckbox :: Bool -> String -> n -> Bool -> Bool -> Widget n
renderCheckbox isEnabled label n foc val =
    let addAttr = if foc then withDefAttr focusedFormInputAttr else id
        csr = if foc then showCursor n (Location (1,0)) else id
    in if isEnabled
           then clickable n $ addAttr $ csr $ str $
               "⟬" <> (if val then "✔" else " ") <> "⟭" <> " " <> label
           else withAttr disabledAttr $ str $ "⟬ ⟭ " <> label

disabledAttr :: AttrName
disabledAttr = "disabled"
