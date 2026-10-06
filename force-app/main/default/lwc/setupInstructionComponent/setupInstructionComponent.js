import { LightningElement, api, track } from 'lwc';
import { loadStyle, loadScript, unloadStyle } from 'lightning/platformResourceLoader';
import bootstrap from '@salesforce/resourceUrl/Bootstrap5';
import appLogo from '@salesforce/resourceUrl/appIcon';
import { NavigationMixin } from 'lightning/navigation';


export default class SetupInstructionComponent extends NavigationMixin(LightningElement) {
  
    @api steps = [];
    @track isResourceRender = false;
    @track progressStepMap = { currentStep: 1, isStepsVisible: false, totalSteps: 3 };
    @track appIcon = appLogo;

    connectedCallback() {
    }

    renderedCallback() {
        if (this.isResourceRender)
            return;

        Promise.all([
            loadStyle(this, bootstrap + '/bootstrap-5.0.2-dist/global.css'),
            loadScript(this, bootstrap + '/bootstrap-5.0.2-dist/js/bootstrap.min.js'),
        ]).then(() => {
            window.console.log('Files loaded.');
            this.isResourceRender = true;
        }).catch(error => {
            window.console.log("Error " + error.body.message);
            this.isResourceRender = true;
        });
    }

    handleClick(event) {
        var eventType = event.currentTarget.dataset.type;
        this.isResourceRender = true;
        switch (eventType) {
            case 'back':
                if (+this.progressStepMap.currentStep == 1)
                    this.progressStepMap.isStepsVisible = false;
                else
                    +this.progressStepMap.currentStep--;
                break;
            case 'next':
                +this.progressStepMap.currentStep++;
                break;

            case 'continue':
                this.progressStepMap = { currentStep: 1, isStepsVisible: true, totalSteps: 3 }
                break;
        }
        this.isResourceRender = false;
    }

    get hideNextBtn(){
        return (+this.progressStepMap.currentStep >= this.progressStepMap.totalSteps);
    }

    get stepValue(){
        return `step${this.progressStepMap.currentStep}`;
    }

    get isfirstStep(){
        return +this.progressStepMap.currentStep === 1;
    }

    get isSecondStep(){
        return +this.progressStepMap.currentStep === 2;
    }

    get isThirdStep(){
        return +this.progressStepMap.currentStep === 3;
    }

    closeModal(){
        this.progressStepMap.isStepsVisible = false;
    }
}