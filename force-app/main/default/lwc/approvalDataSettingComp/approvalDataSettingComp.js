import { LightningElement } from "lwc";
import getObjects from "@salesforce/apex/RSOCL_ApprovalDataSettingController.getObjects";
import getFields from "@salesforce/apex/RSOCL_ApprovalDataSettingController.getFields";
import saveApproveSettings from "@salesforce/apex/RSOCL_ApprovalDataSettingController.saveApproveSettings";
import { NavigationMixin } from "lightning/navigation";
import { ShowToastEvent } from "lightning/platformShowToastEvent";

export default class ApprovalDataSettingComp extends NavigationMixin(
  LightningElement
) {
  data;
  error;
  objects = [];
  fields = [];
  showModal;
  dataArray = [];
  selectedOption;
  selectedOptionsList;
  showRecordExistMsg = false;
  approveSettingsData = {};
  showSpinner;
  isResourceRender = false;
  connectedCallback() {
    this.getsObjectsName();
  }

  getsObjectsName() {
    getObjects()
      .then((result) => {
        console.log("result#" + JSON.stringify(result));
        this.data = result;
        if (this.data && this.data?.length > 0) {
          this.dataArray = this.data;
          let tempArray = [];
          this.dataArray.forEach(function (element) {
            var option = {
              label: element.objLabel,
              value: element.objName
            };
            tempArray.push(option);
          });
          tempArray.sort((a, b) => a.label.localeCompare(b.label));
          this.objects = tempArray;
          console.log("objects#" + JSON.stringify(this.objects));
        }
      })
      .catch((error) => {
        console.error("error#" + error);
      });
  }

  handleObjectChange(event) {
    this.showRecordExistMsg = false;
    this.selectedOption = event.detail.value;
    getFields({ objectName: this.selectedOption })
      .then((result) => {
        this.dataArray = result;
        if (this.dataArray && this.dataArray?.length > 0) {
          let tempArray = [];
          this.dataArray.forEach(function (element) {
            var option = {
              label: element.fieldLabel,
              value: element.fieldName
            };
            tempArray.push(option);
          });
          tempArray.sort((a, b) => a.label.localeCompare(b.label));
          this.fields = tempArray;
        }
      })
      .catch((error) => {
        this.error = error;
      });
  }

  handleFieldChange(event) {
    this.selectedOptionsList = event.detail.value;
    console.log("selectedOptionsList***", this.selectedOptionsList);
    console.log(
      "selectedOptionsList***",
      JSON.stringify(this.selectedOptionsList)
    );
  }

  showApprovalDataCreatePopup() {
    this.resetModel();
    this.getsObjectsName();
    this.showModal = true;
  }

  createLetsApproveSettingRecord() {
    console.log("selectedOption***", JSON.stringify(this.selectedOption));
    console.log("selectedOption->>>>", this.selectedOption);
    this.showSpinner = true;
    if (this.selectedOption === undefined) {
      console.log("in if......");
      this.showSpinner = false;
      const title = "ERROR";
      const variant = "error";
      const mode = "dismissable";
      const message = "Please Select Object";
      this.showNotification(title, message, variant, mode);
    } else {
      saveApproveSettings({
        objectName: this.selectedOption,
        fieldList: JSON.stringify(this.selectedOptionsList)
      })
        .then((result) => {
          console.log("result***" + JSON.stringify(result));
          this.approveSettingsData = result;
          if (this.approveSettingsData.status === "Existing Record") {
            this.showRecordExistMsg = true;
            this.showSpinner = false;
            return;
          } else if (this.approveSettingsData.status === "SUCCESS") {
            console.log("IN SUCCESS...");
            this.showSpinner = false;
            const recId = this.approveSettingsData.recordId;
            console.log("recId***", recId);
            const recordName = this.approveSettingsData.recordName;
            const title = "SUCCESS";
            const variant = "success";
            const mode = "sticky";
            //this.showNotification(title, message, variant, mode);
            this.showNotificationForCreation(
              title,
              variant,
              mode,
              recId,
              recordName
            );
            // eval("$A.get('e.force:refreshView').fire();");
          } else if (this.approveSettingsData.status === "FAILED") {
            this.showSpinner = false;
            const title = "ERROR";
            const variant = "error";
            const mode = "dismissable";
            const message = "There is an error creating records.";
            this.showNotification(title, message, variant, mode);
            // eval("$A.get('e.force:refreshView').fire();");
          }

          this.showModal = false;
        })
        .catch((error) => {
          this.showModal = false;
          this.error = error;
        });
    }
  }

  showNotification(title, message, variant, mode) {
    const evt = new ShowToastEvent({
      title: title,
      message: message,
      variant: variant,
      mode: mode
    });
    this.dispatchEvent(evt);
  }

  closeModal() {
    this.showModal = false;
    // eval("$A.get('e.force:refreshView').fire();");
  }

  openRecordInNewTab() {
    this[NavigationMixin.GenerateUrl]({
      type: "standard__recordPage",
      attributes: {
        recordId: this.approveSettingsData.recordId,
        objectApiName: "Approval_Data_Setting__c",
        actionName: "view",
        tabName: "details"
      }
    }).then((generatedUrl) => {
      window.open(generatedUrl);
    });
    // eslint-disable-next-line no-eval
    eval("$A.get('e.force:refreshView').fire();");
    //this.showModal = true;
  }

  showNotificationForCreation(title, variant, mode, recId, recordName) {
    console.log("IN showNotificationForCreation....... ");
    const event = new ShowToastEvent({
      title: title,
      message: "Record {0} created Sucessfully ! Click {1} to view record!",
      variant: variant,
      mode: mode,
      messageData: [
        recordName,
        {
          url: "/" + recId,
          label: "here"
        }
      ]
    });
    this.dispatchEvent(event);
  }

  resetModel() {
    this.objects = [];
    this.fields = [];
    this.selectedOptionsList = [];
    this.showRecordExistMsg = false;
  }
}
