import { LightningElement } from 'lwc';

export default class EmailAutomationService extends LightningElement {

    videoUrl =
        'https://www.youtube.com/embed/8jQ7_aV4wI8';

    get hasVideo() {
        return this.videoUrl;
    }

}