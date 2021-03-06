import React, { Component, PropTypes } from 'react';
import { connect } from 'react-redux';
import { createStructuredSelector } from 'reselect';

import PlaylistTrackView from '../../view/playlist/track';

import { playTrack, selectTrack, deletePreviousPlayer, setActiveTrack } from '../../actions';
import { makeSelectTrackDatabyId } from '../../selectors';


// import debugRender from 'react-render-debugger';
// @debugRender
class PlaylistTrackContainer extends Component {
    handleSelectTrackClick = (event) => {
        const { trackData } = this.props;
        event.preventDefault();
        event.stopPropagation();
        this.props.deletePreviousPlayer();
        this.props.setActiveTrack(trackData.trackId);
        this.props.playTrack(trackData.file);
    }

    handleDeleteTrackClick = (event) => {
        const { trackData } = this.props;
        event.preventDefault();
        event.stopPropagation();
        this.props.selectTrack(trackData.albumId, trackData.trackId, true);
    }

    render() {
        const { trackData, active } = this.props;
        if (_.isEmpty(trackData)) return null;

        return (
            <PlaylistTrackView
                {...trackData}
                active   = {active}
                onPlay   = {this.handleSelectTrackClick}
                onDelete = {this.handleDeleteTrackClick}
            />
        );
    }
}


PlaylistTrackContainer.propTypes = {
    active              : PropTypes.bool.isRequired,
    deletePreviousPlayer: PropTypes.func.isRequired,
    playTrack           : PropTypes.func.isRequired,
    selectTrack         : PropTypes.func.isRequired,
    setActiveTrack      : PropTypes.func.isRequired,
    trackData           : PropTypes.object,
};

const makeMapStateToProps = () => {
    const selectTrackDatabyId = makeSelectTrackDatabyId();

    return createStructuredSelector({
        trackData: selectTrackDatabyId,
    });
};

const mapDispatchToProps = dispatch => ({
    deletePreviousPlayer: () => dispatch(deletePreviousPlayer()),
    playTrack           : url => dispatch(playTrack(url)),
    setActiveTrack      : trackId => dispatch(setActiveTrack(trackId)),
    selectTrack         : (albumId, trackId, selected) => dispatch(selectTrack(albumId, trackId, selected)),
});

export default connect(makeMapStateToProps, mapDispatchToProps)(PlaylistTrackContainer);
