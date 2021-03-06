import React, { Component, PropTypes } from 'react';
import { connect } from 'react-redux';
import { createStructuredSelector } from 'reselect';

import AlbumView from '../../view/content/album';
import TrackContainer from './track';

import { selectAlbum } from '../../actions';
import {
    makeSelectAlbumDatabyId,
    getSelectedTrackIds,
    getActiveTrackId,
} from '../../selectors';

// import debugRender from 'react-render-debugger';
// @debugRender
class AlbumContainer extends Component {
    state = {
        folded: true,
    }

    handleSelectAlbumClick = (event) => {
        event.preventDefault();
        event.stopPropagation();
        this.props.selectAlbum();
    }

    handleUnfold = (event) => {
        event.preventDefault();
        event.stopPropagation();
        this.setState({ folded: !this.state.folded });
    }

    get trackList() {
        if (this.state.folded) return null;
        const { albumId, albumData, selectedTrackIds, activeTrackId } = this.props;
        if (_.isEmpty(albumData.trackIds)) return null;

        const list = albumData.trackIds.map(trackId =>
            <TrackContainer
                active   = {trackId === activeTrackId}
                albumId  = {albumId}
                key      = {trackId}
                selected = {_.includes(selectedTrackIds, trackId)}
                trackId  = {trackId}
            />
        );
        return (
            <div>
                { list }
            </div>
        );
    }

    render() {
        const { albumData, selected } = this.props;
        if (_.isEmpty(albumData)) return null;

        return (
            <AlbumView
                {...albumData}
                folded       = {this.state.folded}
                selected     = {selected}
                handleUnfold = {this.handleUnfold}
                onClick      = {this.handleSelectAlbumClick}
            >
                { this.trackList }
            </AlbumView>
        );
    }
}


AlbumContainer.propTypes = {
    activeTrackId   : PropTypes.number.isRequired,
    albumData       : PropTypes.object,
    albumId         : PropTypes.number.isRequired,
    selectAlbum     : PropTypes.func.isRequired,
    selected        : PropTypes.bool.isRequired,
    selectedTrackIds: PropTypes.arrayOf(PropTypes.number),
};

const makeMapStateToProps = () => {
    const selectAlbumDatabyId = makeSelectAlbumDatabyId();

    return createStructuredSelector({
        albumData       : selectAlbumDatabyId,
        selectedTrackIds: getSelectedTrackIds,
        activeTrackId   : getActiveTrackId,
    });
};

const mapDispatchToProps = (dispatch, ownProps) => ({
    selectAlbum: () => dispatch(selectAlbum(ownProps.albumId, ownProps.selected)),
});

export default connect(makeMapStateToProps, mapDispatchToProps)(AlbumContainer);
