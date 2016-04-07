import Data.String.Utils
import Data.List (sort, nub)
import System.Process (readProcess)
import Data.List.Split (splitOn)
import System.Time.Utils
import System.Time
import System.Locale
import Data.Time.Clock ()
import Control.Monad(liftM)
import Data.Time.Calendar ()
import Data.Time.LocalTime ()
import System.Environment
import System.Exit
import LookupGitDirs (getGitDirectories, getGits)
import DateStuff (generateLastNDays , getTime, makeDateString)
import qualified Data.Set as Set

type ActualDays = [String]

lastN :: Int -> [a] -> [a]
lastN n xs = foldl (const .drop 1) xs (drop n xs)

getCommitDates :: String -> IO [ClockTime]
getCommitDates repoPath = do
  hout <- readProcess "git" ["--git-dir", repoPath, "log", "--pretty=format:\"%at\""] "."
  let x =  splitOn "\n" hout
  return $ map (epochToClockTime . read . replace "\"" "") x

updateGitHooks :: IO ()
updateGitHooks = do
  gitDirs <- getGitDirectories
  results <- mapM (\dir -> readProcess "cp" ["/home/jack/.git_template/hooks/post-commit", dir ++ "/hooks/."] ".") gitDirs
  putStrLn . (++ " Success!") . concat $ results

convertClockToString :: ClockTime -> IO String
convertClockToString clk = do
  ct <- toCalendarTime clk
  return $ formatCalendarTime defaultTimeLocale "%Y-%m-%d" ct

firstMissing :: Set.Set String -> Set.Set String -> String
firstMissing expected actual =
  head $ Set.toList $ Set.difference expected actual

getLastNGitCommitDays :: Int -> IO ActualDays
getLastNGitCommitDays n = do
  gitDirs <- getGitDirectories
  times <- mapM getCommitDates gitDirs
  liftM (lastN n . nub) $ mapM convertClockToString . sort . concat $ times

getOldestMissingStr :: IO String
getOldestMissingStr = do
  actual <- Set.fromList <$> getLastNGitCommitDays 40
  expected <- Set.fromList <$> generateLastNDays 40

  if expected == actual then return ""
  else do
    time <- getTime
    return $ makeDateString time $ firstMissing expected actual

getAllMissingStr :: IO String
getAllMissingStr = do
  actual <- getLastNGitCommitDays 40
  expected <- generateLastNDays 40
  time <- getTime
  let missing = Set.difference (Set.fromList expected) (Set.fromList actual)
  return $ Set.fold (\d ret -> makeDateString time d ++ "\n" ++ ret) "" missing

getOldestMissing :: IO ()
getOldestMissing = getOldestMissingStr >>= putStrLn

getDayString :: String -> Set.Set String -> String
getDayString expected actuals =
  if Set.member expected actuals then "X" else "_"

printBashGui :: IO ()
printBashGui =  getBashGui >>= putStrLn

getBashGui :: IO String
getBashGui = do
  actualDays <- getLastNGitCommitDays 30
  expectedDays <- generateLastNDays 30
  let actual = Set.fromList actualDays
  return $ foldl (\acc next -> acc ++ getDayString next actual) "" expectedDays

updateGitBashGui :: IO ()
updateGitBashGui = do
  gui <- getBashGui
  writeFile "/home/jack/programming/haskell-course/guifile" gui

printSingleGitCurrent :: String -> (String, [String]) -> String
printSingleGitCurrent _ (_ , []) = ""
printSingleGitCurrent dateStr (path, shas) =
  let oldest = head . lastN 1 $ shas
      total = show . length $ shas
  in total ++ ": cd " ++ path ++ " && cd .. && "
     ++ " git checkout master && git merge " ++ oldest
     ++ " && git commit --amend " ++ dateStr
     ++ " && git checkout current && git rebase master"

printGitDirsWithCurrents :: IO ()
printGitDirsWithCurrents = do
  dateStr <- getOldestMissingStr
  output <- getGits
  putStrLn $ concatMap (printSingleGitCurrent dateStr) output

main :: IO ()
main = getArgs >>= parse

parse :: [String] -> IO ()
parse ["-h"] = usage   >> exit
parse ["-v"] = version >> exit
parse ["-ca"] = getOldestMissing
parse ["-c"] = getAllMissingStr >>= putStrLn
               >> getBashGui >>= putStrLn
parse ["-b"] = printBashGui
parse ["-u"] = updateGitHooks
parse ["-w"] = updateGitBashGui
parse ["-r"] = printGitDirsWithCurrents
parse [] = usage >> exit

usage :: IO ()
usage   = putStrLn "Usage: dateParser \n [-v version]\n [-h help]\n [-c find oldest missing]\n [-b print bash gui] \n [-w write bash file] \n [-u update all git hooks] \n [-r find rebase commits in current]"
version :: IO ()
version = putStrLn "Haskell dateParser 1.0"
exit :: IO a
exit    = exitSuccess
die :: IO a
die     = exitWith (ExitFailure 1)

testClone :: IO ()
testClone =
  let url = ""
      cmd = "cd /home/jack/programming && git clone " ++ url
  in putStrLn cmd

  -- let actualDays = ["2015-04-08","2015-04-09","2015-04-10","2015-04-11" ,"2015-04-12","2015-04-13","2015-04-14","2015-04-15","2015-04-16","2015-04-17","2015-04-18","2015-04-19","2015-04-20","2015-04-21","2015-04-22","2015-04-23","2015-04-24","2015-04-25","2015-04-26","2015-04-27"]
  -- let expectedDays = ["2015-04-08","2015-04-09","2015-04-10","2015-04-11","2015-04-12","2015-04-13","2015-04-14","2015-04-15","2015-04-16","2015-04-17","2015-04-18","2015-04-19","2015-04-20","2015-04-21","2015-04-22","2015-04-23","2015-04-24","2015-04-25","2015-04-26","2015-04-27"]
