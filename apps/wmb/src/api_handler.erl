%% Feel free to use, reuse and abuse the code in this file.

%% @doc API handler
-module(api_handler).

-export([init/3]).
-export([handle/2]).
-export([terminate/3]).

-include("ets_names.hrl").

init(_Type, Req, []) ->
	{ok, Req, undefined}.

handle(Req, State) ->
        {Path, Req1} = cowboy_req:path(Req),
        [_, _, APIType, APIid] = binary:split(Path, [<<"/">>], [global]),
        io:format("Path Elements: ~p~n", [[APIType, APIid]]),

        [[AlbumID, {file, File}, Title]] = ets:match(?ETS_TRACKS, {'$1', {'$2', '$3', {track_id, binary_to_integer(APIid)}}}),
        [{AlbumID, {cover, AlbumCover}}] = ets:lookup(?ETS_COVERS, AlbumID),
        [{AlbumID, {path, AlbumPathBin}}] = ets:lookup(?ETS_PATHS, AlbumID),
        [[{AlbumTuple, DateTuple}]] = ets:match(?ETS_ALBUMS, {'$1', AlbumID}),
        [{AlbumID, AlbumArtist}] = ets:lookup(?ETS_ARTISTS, AlbumID),
        FileBin      = unicode:characters_to_binary(File),
        FilesUrlRoot = <<"/files/">>,
        io:format("TrackInfo: ~p~n", [[AlbumID, Title, AlbumPathBin, AlbumCover, AlbumArtist]]),
        UrlCover = <<FilesUrlRoot/binary, AlbumPathBin/binary, <<"/">>/binary, AlbumCover/binary>>,
        UrlFile  = <<FilesUrlRoot/binary, FileBin/binary>>,

	Res = jsx:encode([{file, UrlFile}, {cover, UrlCover}, AlbumArtist, AlbumTuple, DateTuple, Title]),

	{ok, Req2} = cowboy_req:reply(
                   200,
                   [{<<"content-type">>, <<"application/json">>}],
	               Res,
                   Req),
	{ok, Req2, State}.

terminate(_Reason, _Req, _State) ->
	ok.