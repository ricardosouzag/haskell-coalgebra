{-# LANGUAGE FlexibleInstances, TypeFamilies #-}

module Quiver (
    Quiver (..),
    Vertex(..),
    Arrow(..),
    Path(..),
    Comp(..),
    (#),
    (%),
    maxPathLength,
    getAllPaths,
    hasCycles
    ) where
    
    -- Begin Exported

        -- Vertices only have names
        data Vertex = Vertex {
            vertexName :: String
        }

        -- Arrows have names, source and target
        data Arrow = Arrow {
            arrowName :: String,
            arrowSource :: Vertex,
            arrowTarget :: Vertex
        }

        -- Quivers are a collection of vertices and arrows connecting them
        data Quiver = Quiver {
            quiverName :: String,
            vertices :: [Vertex],
            arrows :: [Arrow]
        }

        -- Paths are collections of composable arrows
        data Path = Path {
            pathName :: String,
            pathArrows :: [Arrow]
        }

        -- Actual definition of how to compose two composable types
        (#) :: (Comp a, Comp b) => a->b->Path
        (#) a b = toPath (a,b)

        -- The inverse operation to composing
        -- Breaks a path into all its possible subpaths
        (%) :: Path -> [(Path,Path)]
        (%) p = map (mapPair longComp longComp) (splitPath p)

        -- Gets the maximum size of a path in a quiver
        maxPathLength :: Quiver -> Int
        maxPathLength (Quiver n vs []) = 0
        maxPathLength (Quiver _ _ as) = length as

        -- Gets all the paths in a finite quiver
        getAllPaths :: Quiver -> [Path]
        getAllPaths = filterEmptyPaths.getAllPathsUnfiltered

        -- Checks if a quiver has cycles
        -- This works because in a set with "n" symbols, the maximal word with distinc symbols has precisely all the symbols
        -- So if a path has more than maxPathLegth arrows, we know it's a cycle
        hasCycles :: Quiver -> Bool
        hasCycles (Quiver n vs []) = False
        hasCycles q = filterEmptyPaths(getPaths(getWords q ((maxPathLength q)+1))) /= []

    -- End Exported

    -- Begin Auxiliary

        -- "Composable" class of things that can be concatenated
        class Comp a where
            source :: a -> Vertex
            target :: a -> Vertex
            toPath :: a -> Path

        -- Redefining the show for each type
        -- Can be easily rewritten to show different things
        instance Show Vertex where
            show (Vertex s) = s

        -- Show arrow is done by literally drawing the arrow between its source and target vertices
        -- so we need some string manipulation
        instance Show Arrow where
            show (Arrow a s t) = show s ++ " -" ++ a ++ "-> " ++ show t

        instance Show Path where
            show (Path "" []) = "Empty path"
            show (Path n as) = n ++ ": " ++ pathJoin as

        -- Sadly we cannot draw the quivers as they will, more often than not, be non-planar
        instance Show Quiver where
            show (Quiver s v a) = "Quiver " ++ s ++ ": {Vertices: " ++ (strJoin ", " (map show v)) ++ ". Arrows: " ++ (strJoin ", " (map show a)) ++ "}"

        -- Redefining equality for our types
        instance Eq Vertex where
            (Vertex s) == (Vertex t) = s == t

        instance Eq Arrow where
            (Arrow n s t) == (Arrow m d y) = n == m && s == d && t == y

        instance Eq Path where
            (Path n as) == (Path m bs) = as == bs

        instance Eq Quiver where
            (Quiver n vs as) == (Quiver m ws bs) = n == m && vs == ws && as == bs

        -- Defining how to compose each composable type
        instance Comp Path where
            source = source . head . pathArrows
            target = target . last . pathArrows
            toPath = id        

        instance Comp Vertex where
            source = id
            target = id
            toPath = stationaryPath

        instance Comp Arrow where
            source = arrowSource
            target = arrowTarget
            toPath = arrowPath

        -- Now we define pairs of composable types as also being composable
        instance (Comp a, Comp b) => Comp (a,b) where
            source (a,b) = source a
            target (a,b) = target b
            toPath (a,b) = (toPath a)<+>(toPath b)    

        -- Basic path composition
        (<+>) :: Path->Path->Path
        x<+>y
                | target x == source y = Path {pathName = (pathName x ++ pathName y), pathArrows = (pathArrows x ++ pathArrows y)}
                | otherwise = emptyPath    

        -- Maps a pair of maps "f :: a->c" and "g :: b->d" to a pair "(a,b)" to obtain a pair "(c,d)"
        mapPair :: (a-> c)->(b-> d)->(a,b)->(c, d)
        mapPair f g (x,y) = (f x, g y)
    
        -- Breaks a path into pairs of lists of arrows
        -- Needed for the path decomposition function
        splitPath :: Path->[([Arrow],[Arrow])]
        splitPath p = successiveMap splitAt (length (pathArrows p)) (pathArrows p)

        -- Apply a function "f", which depends on a number "m" and a parameter "a", "m" times, recording the outputs in a list
        -- Can be easily changed to differentiate between the parameter "m" and the number of runs of the function
        -- by changing the signature to (Int->a->b)->(Int->Int)->Int->a->Int->[b]
        successiveMap :: (Int->a->b)->Int->a->[b]
        successiveMap f (-1) x = []
        successiveMap f m x = (map (const(f m x)) [1]) ++ (successiveMap f (m-1) x)
        
        -- Gets all the possible words of arrows in the quiver with a given number of letters
        getWords :: Quiver -> Int -> [[Arrow]]
        getWords (Quiver n vs []) _ = []
        getWords q n  = mapM (const $ arrows q) [1..n]

        -- Generalizes composition of two arrows to a finite list of arrows
        longComp :: [Arrow]->Path
        longComp [] = emptyPath
        longComp [x] = toPath x
        longComp (x:xs) = x#longComp xs

        -- Tries to compose all words of arrows
        getPaths :: [[Arrow]]->[Path]
        getPaths [] = []
        getPaths (x:xs) = [longComp x] ++ getPaths xs

        -- Improvised while loop
        -- Can probably be made much better
        while :: Int -> (Int -> Bool) -> (Int -> [a]) -> [a]
        while start condition f
            | condition start = f start
            | otherwise = f start ++ while (start + 1) condition f    

        -- Basic check for empty
        isEmptyPath :: Path->Bool
        isEmptyPath = (emptyPath ==)

        -- Runs getPath.getWords for a given quiver looking for paths of all sizes (up to maxPathLength)
        getAllPathsUnfiltered :: Quiver -> [Path]
        getAllPathsUnfiltered (Quiver n vs []) = []
        getAllPathsUnfiltered q =  while 1 (== maxPathLength q) (getPaths.(getWords q))

        -- The list returned by getAllPathsUnfiltired will, most like than not, be filled with "emptyPaths"
        -- This removes them, leaving only a list with proper paths
        filterEmptyPaths :: [Path] -> [Path]
        filterEmptyPaths = filter (/= emptyPath)


        -- Used in Show Arrow
        strJoin sep arr = case arr of
            [] -> ""
            [x] -> x
            (x : xs) -> x ++ sep ++ strJoin sep xs
        -- Used in Show Path
        pathJoin arr = case arr of
            [] -> ""
            [x] -> vertexName (arrowSource x) ++ " -" ++ arrowName x ++ "-> " ++ vertexName (arrowTarget x)
            (x : xs) -> vertexName (arrowSource x) ++ " -" ++ arrowName x ++ "-> " ++ pathJoin xs
        

        -- The empty path will be useful
        emptyPath :: Path
        emptyPath = Path {pathName = "", pathArrows = []}

        -- The "do nothing" path at a vertex that corresponds to "staying at home at the vertex"
        stationaryPath :: Vertex->Path
        stationaryPath v = Path {pathName = "", pathArrows = []}

        -- The basic paths corresponding to each arrow
        arrowPath :: Arrow -> Path
        arrowPath a = Path {pathName = arrowName a, pathArrows = [a]}

    -- End Auxiliary