import { LightningElement, track, api } from 'lwc';
import getSubmittedApprovals from '@salesforce/apex/RSOCL_MultipleApprovalController.getSubmittedApprovalRecords';
import processApprovalRecords from '@salesforce/apex/RSOCL_MultipleApprovalController.processRecords';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import SystemModstamp from '@salesforce/schema/Account.SystemModstamp';
import FORM_FACTOR from '@salesforce/client/formFactor';
import bootstrap from '@salesforce/resourceUrl/Bootstrap5';
import { loadStyle, loadScript } from 'lightning/platformResourceLoader';

export default class MassApprovalComponent extends NavigationMixin(LightningElement) {

    @track data;
    @track tableDataArray = [];
    showSpinner = false;
    disableApproveBtn = false;
    disableRejectBtn = false;
    @track _sortedBy = 'objectName';
    @track sortDirection = 'asc';
    @track showModal = false;
    @track uncommentedRecords = [];
    @track isGrandParentSelected = false;
    @track isResourceRender = false;
    _expendedObjectsMap = {};
    _totalSelectedRecordsMap = {};
    modalContainer = false;
    dataRecordRow = [];
    fieldData = [];
    recordIdStr;
    recordObjApiName;
    selectedApprovalRec = [];
    _currentCommentRow = {};
    addCommentForAllMessage;
    showNoRecordsToDisplay = false;

    connectedCallback() {
        console.log('IN connectedCallback...........');
        this.getSubmittedApprovals();
        this.handleFormFactor();
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

    handleFormFactor(){
        if (FORM_FACTOR === "Large") {
            this.deviceType = "Desktop";
        } else if (FORM_FACTOR === "Medium") {
            this.deviceType = "Tablet";
        } else if (FORM_FACTOR === "Small") {
            this.deviceType = "Mobile";
        }
    }

    getSubmittedApprovals() {
        this.showSpinner = true;
        getSubmittedApprovals().then(result => {
            console.log('result#' + result);
            this.data = result;
            this.tableDataArray = [];
            this._totalSelectedRecordsMap = {};
            this.uncommentedRecords = [];
            if (this.data && this.data?.length > 0) {
                this.data.forEach(row => {
                    row.isSelected = false;
                    row.comment = '';
                    var index = this.tableDataArray.findIndex(x => x.objectName == row.relatedTo);
                    if (index > -1)
                        this.tableDataArray[index].childRecords.push(row);
                    else
                        this.tableDataArray.push({
                            objectName: row.relatedTo,
                            childRecords: new Array(row),
                            isSelected: false
                        });
                })
            }
            else{
                this.showNoRecordsToDisplay = true;
            }
            console.log('tableDataArray**', JSON.stringify(this.tableDataArray));
            this.showSpinner = false;
        })
        .catch(error => {
            console.log('error',error);
            this.showSpinner = false;
        });
    }

    

    handleChildRowDisplayAction(event) {
        this.showSpinner = true;
        var id = event.target.dataset.id;
        console.log('id***', id);
        var displayProp = event.target.dataset.val;
        console.log('displayProp***', displayProp);

        if (id)
            this._expendedObjectsMap[id] = (displayProp == 'show' ? true : false);
        console.log('_expendedObjectsMap[id]***', this._expendedObjectsMap[id]);
        this.showSpinner = false;
    }


    selectRecord(event) {
        var index = event.target.dataset.index;
        var recordType = event.target.dataset.type;
        var name = event.target.dataset.name;
        var isSelected = event.target.checked;
        if (recordType == 'parent' && +index >= 0) {
            this.tableDataArray[+index].isSelected = isSelected;
            this.tableDataArray[+index].childRecords.forEach(data => { data.isSelected = isSelected });
            if (name) {
                this._totalSelectedRecordsMap[name] = (isSelected ? this.tableDataArray[+index].childRecords.length : 0);
            }
        }
        else if (recordType == 'child' && +index >= 0) {
            var childIndex = event.target.dataset.childindex;
            var isAllChildSelected = true;
            this.tableDataArray[+index].childRecords.forEach((data, index) => {
                if (index == +childIndex)
                    data.isSelected = isSelected;

                if (!data.isSelected)
                    isAllChildSelected = false;
            })
            this.tableDataArray[+index].isSelected = isAllChildSelected;
            if (name) {
                if (!this._totalSelectedRecordsMap[name])
                    this._totalSelectedRecordsMap[name] = (isSelected ? 1 : 0);
                else
                    this._totalSelectedRecordsMap[name] += (isSelected ? 1 : -1);
            }
        }
        else if (recordType == 'grand-parent') {
            this.tableDataArray.forEach(data => {
                data.isSelected = isSelected;
                data.childRecords.forEach(childData => { childData.isSelected = isSelected });
                this._totalSelectedRecordsMap[data.objectName] = (isSelected ? data.childRecords.length : 0);
            });
            this.isGrandParentSelected = isSelected;
        }

        if (!(recordType == 'grand-parent')) {
            var index = this.tableDataArray.findIndex(data => data.isSelected == false);
            this.isGrandParentSelected = (index >= 0) ? false : true;
        }
        this.showSpinner = false;
    }

    handleRowAction(event) {
        const action = event.detail.action;
        const row = event.detail.row;

        switch (action?.id) {
            case 'addComment':
                this._currentCommentRow = row;
                this.showModal = true;
                break;
        }
    }

    async handleSortdata(event) {
        // event.preventDefault();
        this.showSpinner = true;
        var parentDataName;
        try {
            const sortBy = event.target.dataset.sortby;
            const parentIndex = event.target.dataset.parentindex;
            if (sortBy == this._sortedBy) {
                this.sortDirection = this.sortDirection == 'asc' ? 'desc' : 'asc';
            } else {
                this._sortedBy = sortBy;
                this.sortDirection = 'asc';
            }

            if (+parentIndex >= 0) {
                this.tableDataArray[+parentIndex].childRecords.sort((a, b) => {
                    const aVal = a[this._sortedBy];
                    const bVal = b[this._sortedBy];
                    if (aVal > bVal) {
                        return this.sortDirection === 'asc' ? 1 : -1;
                    } else if (aVal < bVal) {
                        return this.sortDirection === 'asc' ? -1 : 1;
                    } else {
                        return 0;
                    }
                });
                parentDataName = this.tableDataArray[+parentIndex].objectName;
            }
            else {
                this.tableDataArray.sort((a, b) => {
                    const aVal = a[this._sortedBy];
                    const bVal = b[this._sortedBy];
                    if (aVal > bVal) {
                        return this.sortDirection === 'asc' ? 1 : -1;
                    } else if (aVal < bVal) {
                        return this.sortDirection === 'asc' ? -1 : 1;
                    } else {
                        return 0;
                    }
                });
            }
            console.log(sortBy);
            const selector = parentDataName ? `table[data-parentname=${parentDataName}] thead button[data-sortby=${sortBy}]` : `button[data-sortby=${sortBy}]`;
            var template = await this.template.querySelector(selector);
            await template.setAttribute('data-sortdirection', this.sortDirection);
            this.showSpinner = false;
        }
        catch (e) {
            this.showSpinner = false;
            console.error('error on sort---', e?.toString());
        }
    }

    onclickAddCommentBtn(event) {
        this.showModal = true;
        const objName = event.currentTarget.dataset.name;
        console.log('objName***', objName);
        this.addCommentForAllMessage = 'Do you want to add same comment for all ' + objName + ' records'
        const itemIndex = event.currentTarget.dataset.index;
        console.log('itemIndex***', itemIndex);


        var data = this.tableDataArray;
        data.forEach(row => {
            if (row.objectName == objName) {
                this._currentCommentRow = row.childRecords[itemIndex];
            }
        })
        console.log('_currentCommentRow***', JSON.stringify(this._currentCommentRow));
    }

    addComment() {
        try {
            const value = this.template.querySelector('[data-id="commentBox"]').value;
            console.log('value***', value);
            const addcommentforall = this.template.querySelector('[data-id="checkBoxforAllComment"]').checked;
            console.log('addcommentforall***', addcommentforall);
            console.log('_currentCommentRow->>>', JSON.stringify(this._currentCommentRow));
            console.log('workItemId->>>', JSON.stringify(this._currentCommentRow.workItemId));
            var data = [...this.tableDataArray];
            console.log('data***', JSON.stringify(data));
            if (value && !addcommentforall) {
                data.forEach(row => {
                    let currentCommentRowWorkItemId = this._currentCommentRow.workItemId;
                    console.log('currentCommentRowWorkItemId***', currentCommentRowWorkItemId);
                    let currentRowObjName = this._currentCommentRow.relatedTo;
                    console.log('currentRowObjName***', currentRowObjName);
                    if (row.objectName == currentRowObjName) {
                        var index = row.childRecords.findIndex(x => x.workItemId === currentCommentRowWorkItemId);
                        console.log('index***', index);
                        row.childRecords[index].comment = value;
                    }
                })
            }
            else {
                data.forEach(row => {
                    let currentRowObjName = this._currentCommentRow.relatedTo;
                    console.log('currentRowObjName***', currentRowObjName);
                    if (row.objectName == currentRowObjName) {
                        row.childRecords.forEach(function (childRec) {
                            childRec.comment = value;
                        })
                    }
                })
            }
            this.tableDataArray = data;
            console.log(JSON.stringify(this.tableDataArray))
            this._currentCommentRow = {};
            this.showModal = false;
        } catch (e) {
            console.error('error message:', e);
        }
    }

    closeModal() {
        this.showModal = false;
    }

    handleApproveAction() {
        try {
            this.disableApproveBtn = true;
            var childRecords = [];
            var data = this.tableDataArray;
            data.forEach(row => {
                row.childRecords.forEach(function (childRec) {
                    if (childRec.isSelected) {
                        childRecords.push(childRec);
                    }
                })
            })
            console.log('childRecords****', childRecords);
            console.log('childRecords length****', childRecords.length);
            if (childRecords.length <= 0) {
                const evt = new ShowToastEvent({
                    title: 'Error',
                    message: 'Please select items to Apporve.',
                    variant: 'error',
                    mode: 'sticky'
                });
                this.dispatchEvent(evt);
                this.disableApproveBtn = false;
            }
            if (childRecords.length > 0) {
                var selectedRows = [];
                for (var i = 0; i < childRecords.length; i++) {
                    console.log('selected[i]**', childRecords[i]);
                    selectedRows.push({ workItemId: childRecords[i].workItemId, comment: childRecords[i].comment });
                }
                console.log('selectedRows***', selectedRows);
                var message;
                processApprovalRecords({ lstWorkItemIds: JSON.stringify(selectedRows), processType: 'Approve' }).then(result => {
                    console.log('result#' + result);
                    message = result;
                    if (message.includes('success')) {
                        var title = 'SUCCESS';
                        var variant = 'success';
                        var mode = 'dismissable';
                        this.showNotification(title, message, variant, mode);
                    }
                    else {
                        var title = 'ERROR';
                        var variant = 'error';
                        var mode = 'dismissable';
                        this.showNotification(title, message, variant, mode);
                    }
                    this.getSubmittedApprovals();
                })
                    .catch(error => {
                        console.log('error#' + error);
                    });
            }
        }
        catch (e) {
            console.error('error message:', e);
        }
    }

    handleRejectAction() {
        try {
            this.disableRejectBtn = true;
            var childRecords = [];
            var data = this.tableDataArray;
            data.forEach(row => {
                row.childRecords.forEach(function (childRec) {
                    if (childRec.isSelected) {
                        childRecords.push(childRec);
                    }
                })
            })
            console.log('childRecords****', childRecords);
            console.log('childRecords length****', childRecords.length);
            if (childRecords.length <= 0) {
                console.log('now row selected...');
                const evt = new ShowToastEvent({
                    title: 'Error',
                    message: 'Please select items to Reject.',
                    variant: 'error',
                    mode: 'sticky'
                });
                console.log('evt', evt);
                this.dispatchEvent(evt);
                this.disableRejectBtn = false;
            }
            if (childRecords.length > 0) {
                var selectedRows = [];
                for (var i = 0; i < childRecords.length; i++) {
                    selectedRows.push({ workItemId: childRecords[i].workItemId, comment: childRecords[i].comment })
                }
                console.log('selectedRows***', selectedRows);
                var message;
                processApprovalRecords({ lstWorkItemIds: JSON.stringify(selectedRows), processType: 'Reject' }).then(result => {
                    console.log('result#' + result);
                    message = result;
                    if (message.includes('success')) {
                        var title = 'SUCCESS';
                        var variant = 'success';
                        var mode = 'dismissable';
                        this.showNotification(title, message, variant, mode);
                    }
                    else {
                        var title = 'ERROR';
                        var variant = 'error';
                        var mode = 'dismissable';
                        this.showNotification(title, message, variant, mode);
                    }
                })
                    .catch(error => {
                        console.log('error#' + error);
                    });
                setTimeout(() => {
                    eval("$A.get('e.force:refreshView').fire();");
                }, 1000);
            }
        }
        catch (e) {
            console.error('error message:', e);
        }
    }

    checkCommentBeforePrcess() {
        var el = this.template.querySelector('lightning-datatable');
        var selectedRows = el.getSelectedRows();
        selectedRows.forEach(x => {
            if (!x.comment)
                this.uncommentedRecords.push(x);
        })

        if (this.uncommentedRecords.length > 0)
            return false
        else
            return true;
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

    get getTableData() {
        return (this.tableDataArray.map((row, index) => ({
            ...row,
            isExpended: this._expendedObjectsMap[row.objectName],
            totalSelectedRecords: this._totalSelectedRecordsMap[row.objectName] ? `${this._totalSelectedRecordsMap[row.objectName]} out of ${row.childRecords?.length} selected` : row.childRecords?.length

        })));
    }

    closeModalAction() {
        this.modalContainer = false;
    }
    showActualRecordPopup(event) {
        this.modalContainer = true;
        this.recordObjApiName = event.currentTarget.dataset.type;
        this.recordIdStr = event.currentTarget.dataset.val;
        console.log('recordIdStr***', this.recordIdStr);
        console.log('recordObjApiName***', this.recordObjApiName);
    }
    navigateToRecDetailsPage(event) {

        this[NavigationMixin.GenerateUrl]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.recordIdStr,
                objectApiName: this.recordObjApiName,
                actionName: 'view',
                tabName: 'details'
            }
        }).then(generatedUrl => {
            window.open(generatedUrl);
        });
    }

    get isCurrentDeviceMobile(){
        return (FORM_FACTOR === "Small");
    }
}