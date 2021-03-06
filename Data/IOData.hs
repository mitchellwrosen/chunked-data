{-# LANGUAGE CPP          #-}
{-# LANGUAGE TypeFamilies #-}
module Data.IOData where

import           Control.Monad                 (liftM)
import           Control.Monad.IO.Class
import qualified Data.ByteString               as ByteString
import qualified Data.ByteString.Char8         as ByteString8
import qualified Data.ByteString.Lazy          as LByteString
import           Data.ByteString.Lazy.Internal (defaultChunkSize)
import           Data.Sequences                (IsSequence)
import           Data.Sequences.Lazy           (fromStrict)
import qualified Data.Text                     as Text
import qualified Data.Text.IO                  as Text
import qualified Data.Text.Lazy                as LText
import qualified Data.Text.Lazy.IO             as LText
import           Filesystem.Path               (FilePath)
import qualified Filesystem.Path.CurrentOS     as FilePath
import           Prelude                       (Char, flip, ($), (.))
import qualified Prelude
import           System.IO                     (Handle)
import qualified System.IO

#if !MIN_VERSION_text(0, 11, 3)
import           Control.Exception             (handle, throwIO)
import           System.IO.Error               (isEOFError)
#endif

-- | Data which can be read to and from files and handles.
--
-- Note that, for lazy sequences, these operations may perform
-- lazy I\/O.
class IsSequence a => IOData a where
    readFile     :: MonadIO m => FilePath -> m a
    writeFile    :: MonadIO m => FilePath -> a -> m ()
    getLine      :: MonadIO m => m a
    hGetContents :: MonadIO m => Handle -> m a
    hGetLine     :: MonadIO m => Handle -> m a
    hPut         :: MonadIO m => Handle -> a -> m ()
    hPutStrLn    :: MonadIO m => Handle -> a -> m ()
    hGetChunk    :: MonadIO m => Handle -> m a
instance IOData ByteString.ByteString where
    readFile = liftIO . ByteString.readFile . FilePath.encodeString
    writeFile fp = liftIO . ByteString.writeFile (FilePath.encodeString fp)
    getLine = liftIO ByteString.getLine
    hGetContents = liftIO . ByteString.hGetContents
    hGetLine = liftIO . ByteString.hGetLine
    hPut h = liftIO . ByteString.hPut h
    hPutStrLn h = liftIO . ByteString8.hPutStrLn h
    hGetChunk = liftIO . flip ByteString.hGetSome defaultChunkSize
instance IOData LByteString.ByteString where
    readFile = liftIO . LByteString.readFile . FilePath.encodeString
    writeFile fp = liftIO . LByteString.writeFile (FilePath.encodeString fp)
    getLine = liftM fromStrict (liftIO ByteString.getLine)
    hGetContents = liftIO . LByteString.hGetContents
    hGetLine = liftM fromStrict . liftIO . ByteString.hGetLine
    hPut h = liftIO . LByteString.hPut h
    hPutStrLn h lbs = liftIO $ do
        LByteString.hPutStr h lbs
        ByteString8.hPutStrLn h ByteString.empty
    hGetChunk = liftM fromStrict . hGetChunk
instance IOData Text.Text where
    readFile = liftIO . Text.readFile . FilePath.encodeString
    writeFile fp = liftIO . Text.writeFile (FilePath.encodeString fp)
    getLine = liftIO Text.getLine
    hGetContents = liftIO . Text.hGetContents
    hGetLine = liftIO . Text.hGetLine
    hPut h = liftIO . Text.hPutStr h
    hPutStrLn h = liftIO . Text.hPutStrLn h
#if MIN_VERSION_text(0, 11, 3)
    hGetChunk = liftIO . Text.hGetChunk
#else
    -- Dangerously inefficient!
    hGetChunk =
        liftIO . handleEOF . liftM Text.singleton . System.IO.hGetChar
      where
        handleEOF = handle $ \e ->
            if isEOFError e
                then Prelude.return Text.empty
                else throwIO e
#endif
instance IOData LText.Text where
    readFile = liftIO . LText.readFile . FilePath.encodeString
    writeFile fp = liftIO . LText.writeFile (FilePath.encodeString fp)
    getLine = liftIO LText.getLine
    hGetContents = liftIO . LText.hGetContents
    hGetLine = liftIO . LText.hGetLine
    hPut h = liftIO . LText.hPutStr h
    hPutStrLn h = liftIO . LText.hPutStrLn h
    hGetChunk = liftM fromStrict . hGetChunk
instance (Char ~ c) => IOData [c] where
    readFile = liftIO . Prelude.readFile . FilePath.encodeString
    writeFile fp = liftIO . Prelude.writeFile (FilePath.encodeString fp)
    getLine = liftIO Prelude.getLine
    hGetContents = liftIO . System.IO.hGetContents
    hGetLine = liftIO . System.IO.hGetLine
    hPut h = liftIO . System.IO.hPutStr h
    hPutStrLn h = liftIO . System.IO.hPutStrLn h
    hGetChunk = liftM Text.unpack . hGetChunk
