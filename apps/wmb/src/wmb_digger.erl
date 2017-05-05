-module(wmb_digger).

%% Exported Functions
-export([parse_file/1, parse_file/2]).
-export([find_album_cover/1, find_album_cover/2]).
-export([get_album_id/2, get_path_id/2]).

-include("ets_names.hrl").

%%%===================================================================
%%% Exported functions
%%%===================================================================
-spec parse_file(string()) ->
    {ok, {track_id, integer()}} | false.
parse_file(File) ->
    {ok, FilesRoot} = application:get_env(wmb, files_root),
    FilePathFull = lists:concat([FilesRoot, '/', File]),
    parse_file(fullpath, FilePathFull).

-spec parse_file(fullpath, string()) ->
    {ok, {track_id, integer()}} | false.
parse_file(fullpath, FilePathFull) ->
    case flactags:get_tags(FilePathFull) of
        {ok, FileMetadata} ->
            FileID3Tags = maps:get(4, FileMetadata),
            add_to_ets(FilePathFull, FileID3Tags);
        {error, Error} ->
            ets:insert(?ETS_ERRORS, {{file, FilePathFull}, {error, Error}})
    end.

%%%===================================================================
%%% Internal functions
%%%===================================================================
-spec add_to_ets(string(), map()) ->
    {ok, {track_id, integer()}}.
add_to_ets(File, FileID3Tags) ->
    Album  = maps:get(<<"ALBUM">>,  FileID3Tags, <<"Undef_Album">>),
    %% Artist = maps:get(<<"ARTIST">>, FileID3Tags, <<"Undef_Artist">>),
    AlbumArtist = maps:get(<<"ALBUMARTIST">>, FileID3Tags, <<"Undef_Artist">>),
    Genre  = maps:get(<<"GENRE">>,  FileID3Tags, <<"Undef_Genre">>),
    Date   = maps:get(<<"DATE">>,   FileID3Tags, <<"Undef_Date">>),
    Title  = maps:get(<<"TITLE">>,  FileID3Tags, <<"Undef_Title">>),
    {ok, {AlbumPathRelBin, FileBasename}} = wmb_helpers:split_path_and_filename(File),
    TrackID = ets:update_counter(?ETS_COUNTERS, track_id_counter, 1),
    case get_album_id(Album, Date) of
        undefined ->
            AlbumPathFull = filename:dirname(File),
            ArtistID = get_artist_id(AlbumArtist),
            AlbumID = ets:update_counter(?ETS_COUNTERS, album_id_counter, 1),
            PathID = get_path_id(AlbumPathRelBin, AlbumID),
            {ok, AlbumCover} = find_album_cover(AlbumPathFull),
            %io:format("Path & PathID is: ~p~n", [[AlbumPathRelBin, PathID]]),
            ets:insert(?ETS_ALBUMS, {{album_id, AlbumID}, {{album, Album}, {date, Date}, {tracks, [TrackID]}, {path_id, PathID}, {genre, Genre}, {cover, AlbumCover}}}),
            ets:insert(?ETS_ARTISTS, {{album_id, AlbumID}, {{artist, AlbumArtist}, {artist_id, ArtistID}}}),
            ets:insert(?ETS_TRACKS, {{track_id, TrackID}, {{album_id, AlbumID}, {file, FileBasename}, {title, Title}, {path_id, PathID}}}),
            ets:insert(?ETS_GENRES, {{album_id, AlbumID}, {genre, Genre}}),
            %%%io:format("Album Cover is: ~p~n", [AlbumCover]),
            [LetterByte|_] = unicode:characters_to_list(AlbumArtist),
            LetterBin = unicode:characters_to_binary([LetterByte]),
            LetterID = get_letter_id(LetterBin),
            ets:insert(?ETS_ABC, {{{letter_id, LetterID}, {letter, LetterBin}}, {artist, AlbumArtist}});
            %%%io:format("Letters is: ~p~n", [[LetterByte, LetterBin]]);
        ExistedAlbumID ->
            {{album, Album}, {date, Date}, {tracks, TrackIDList}, PathIDTuple, GenreTuple, CoverTuple} = ets:lookup_element(?ETS_ALBUMS, {album_id, ExistedAlbumID}, 2),
            ets:update_element(?ETS_ALBUMS, {album_id, ExistedAlbumID}, {2, {{album, Album}, {date, Date}, {tracks, [TrackID|TrackIDList]}, PathIDTuple, GenreTuple, CoverTuple}}),
            PathID = get_path_id(AlbumPathRelBin, ExistedAlbumID),
            ets:insert(?ETS_TRACKS, {{track_id, TrackID}, {{album_id, ExistedAlbumID}, {file, FileBasename}, {title, Title}, {path_id, PathID}}})
    end,
    {ok, {track_id, TrackID}}.

-spec get_album_id(bitstring(), bitstring()) ->
    undefined | integer().
get_album_id(Album, Date) ->
    case ets:match(?ETS_ALBUMS, {'$1', {{album, Album}, {date, Date}, '_', '_', '_', '_'}}) of
        [] ->
            undefined;
        [[{album_id, AlbumID}]] ->
            AlbumID;
        [[{album_id, AlbumID}]|_] ->
            io:format("ERROR, can't get AlbumID: ~p~n", [[Album, Date]]),
            AlbumID
    end.

-spec get_artist_id(bitstring()) ->
    integer().
get_artist_id(AlbumArtist) ->
    case ets:match(?ETS_ARTISTS, {'_', {{artist, AlbumArtist}, '$1'}}) of
        [] ->
            ArtistID = ets:update_counter(?ETS_COUNTERS, artist_id_counter, 1),
            ArtistID;
        [[{artist_id, ArtistID}]|_] ->
            ArtistID
    end.

-spec get_letter_id(bitstring()) ->
    integer().
get_letter_id(LetterBin) ->
    case ets:match(?ETS_ABC, {{'$1', {letter, LetterBin}}, '_'}) of
        [] ->
            ets:update_counter(?ETS_COUNTERS, letter_id_counter, 1);
        [[{letter_id, LetterID}]|_] ->
            LetterID
    end.

-spec get_path_id(bitstring(), integer()) ->
    integer().
get_path_id(AlbumPathRelBin, AlbumID) ->
    case ets:match(?ETS_PATHS, {'$1', {{path, AlbumPathRelBin}, {album_id, AlbumID}}}) of
        [] ->
            PathID = ets:update_counter(?ETS_COUNTERS, path_id_counter, 1),
            ets:insert(?ETS_PATHS, {{path_id, PathID}, {{path, AlbumPathRelBin}, {album_id, AlbumID}}}),
            PathID;
        [[{path_id, PathID}]] ->
            PathID
    end.

-spec find_album_cover(bitstring()) ->
    {ok, bitstring()}.
find_album_cover(AlbumPathFull) ->
    {ok, PossibleCoversList} = application:get_env(wmb, possible_covers_list),
    find_album_cover(AlbumPathFull, PossibleCoversList).

-spec find_album_cover(bitstring(), list()) ->
    {ok, bitstring()}.
find_album_cover(AlbumPathFull, [PossibleCover|RestPossibleCovers]) ->
    case filelib:is_file(lists:concat([AlbumPathFull, '/', PossibleCover])) of
        true ->
            Cover = unicode:characters_to_binary(PossibleCover),
            {ok, Cover};
        false ->
            find_album_cover(AlbumPathFull, RestPossibleCovers)
    end;
find_album_cover(_AlbumPathFull, []) ->
    {ok, <<"cover_not_found">>}.

