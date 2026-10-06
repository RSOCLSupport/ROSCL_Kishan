import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

export default class AssignPermissionSetComp extends NavigationMixin(LightningElement) {

    @api showAdminPermissionInstruction;

    openSetup() {
        window.open('/lightning/setup/SetupOneHome/home', '_blank');
    }
    openPermisionSetPage(event) {
        event.preventDefault();
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'PermissionSet',
                actionName: 'view',
            },
            state: {
                filterName: event.target.dataset.permsetname,
            },
        });
    }

    get getShowAdminPermissionInstruction(){
        return this.showAdminPermissionInstruction === "true";
    }

    get getUserType(){
        return this.showAdminPermissionInstruction === "true" ? 'Admin' : 'General';
    }
}