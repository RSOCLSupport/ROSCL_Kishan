import { LightningElement } from "lwc";
import getAllSubmittedApprovals from "@salesforce/apex/RSOCL_AdminViewController.getSubmittedApprovalRecordsByAllUsers";
import { NavigationMixin } from "lightning/navigation";

export default class AdminViewComponent extends NavigationMixin(
  LightningElement
) {
  data;
  tableDataArray = [];
  showSpinner = false;
  _expendedObjectsMap = {};
  sortedColumn;
  sortedDirection;
  nameUpBool;
  nameDWBool;
  dateUpBool;
  dateDWBool;
  submiterUpBool;
  submiterDWBool;
  approverUpBool;
  approverDWBool;
  recordIdStr;
  recordObjApiName;
  _currentObject;
  showNoRecordsToDisplay = false;
  connectedCallback() {
    this.showSpinner = true;
    getAllSubmittedApprovals()
      .then((result) => {
        this.data = result;
        if (this.data && this.data?.length > 0) {
          this.data.forEach((row) => {
            var index = this.tableDataArray.findIndex(
              (x) => x.objectName === row.relatedTo
            );
            if (index > -1) this.tableDataArray[index].childRecords.push(row);
            else
              this.tableDataArray.push({
                objectName: row.relatedTo,
                childRecords: new Array(row)
              });
          });
          this.sortedColumn = "recordName";
          this.sortRecs();
        } else {
          this.showNoRecordsToDisplay = true;
        }
        this.showSpinner = false;
      })
      .catch(() => {
        this.showSpinner = false;
        this.data = undefined;
      });
  }

  handleChildRowDisplayAction(event) {
    this.showSpinner = true;
    const id = event.target.dataset.id;
    const displayProp = event.target.dataset.val;

    if (id)
      this._expendedObjectsMap[id] = displayProp === "show" ? true : false;
    this.showSpinner = false;
  }

  get getTableData() {
    return this.tableDataArray.map((row) => ({
      ...row,
      isExpended: this._expendedObjectsMap[row.objectName],
      totalChildRecordCount: row.childRecords?.length
    }));
  }

  sortRecs(event) {
    if (event) {
      this._currentObject = event.target.dataset.type;
    }
    this.nameUpBool = false;
    this.nameDWBool = false;
    this.dateUpBool = false;
    this.dateDWBool = false;
    this.submiterUpBool = false;
    this.submiterDWBool = false;
    this.approverUpBool = false;
    this.approverDWBool = false;

    let colName = event ? event.target.name : undefined;
    if (this.sortedColumn === colName)
      this.sortedDirection = this.sortedDirection === "asc" ? "desc" : "asc";
    else this.sortedDirection = "asc";

    let isReverse = this.sortedDirection === "asc" ? 1 : -1;

    if (colName) this.sortedColumn = colName;
    else colName = this.sortedColumn;

    switch (colName) {
      case "recordName":
        if (this.sortedDirection === "asc") this.nameUpBool = true;
        else this.nameDWBool = true;

        break;

      case "submittedDate":
        if (this.sortedDirection === "asc") this.dateUpBool = true;
        else this.dateDWBool = true;

        break;

      case "submittedBy":
        if (this.sortedDirection === "asc") this.submiterUpBool = true;
        else this.submiterDWBool = true;

        break;

      case "Approver":
        if (this.sortedDirection === "asc") this.approverUpBool = true;
        else this.approverDWBool = true;

        break;

      default:
        break;
    }
    const data = [...this.tableDataArray];
    if (event) {
      data.forEach((row) => {
        if (row.objectName === this._currentObject) {
          row.childRecords = JSON.parse(JSON.stringify(row.childRecords)).sort(
            (a, b) => {
              a = a[colName] ? a[colName].toLowerCase() : "z";
              b = b[colName] ? b[colName].toLowerCase() : "z";
              return a > b ? 1 * isReverse : -1 * isReverse;
            }
          );
        }
      });
    } else {
      data.forEach((row) => {
        row.childRecords = JSON.parse(JSON.stringify(row.childRecords)).sort(
          (a, b) => {
            a = a[colName] ? a[colName].toLowerCase() : "z";
            b = b[colName] ? b[colName].toLowerCase() : "z";
            return a > b ? 1 * isReverse : -1 * isReverse;
          }
        );
      });
    }
    this.tableDataArray = data;
  }

  navigateToRecDetailsPage(event) {
    this.recordObjApiName = event.currentTarget.dataset.type;
    this.recordIdStr = event.currentTarget.dataset.val;

    this[NavigationMixin.GenerateUrl]({
      type: "standard__recordPage",
      attributes: {
        recordId: this.recordIdStr,
        objectApiName: this.recordObjApiName,
        actionName: "view",
        tabName: "details"
      }
    }).then((generatedUrl) => {
      window.open(generatedUrl);
    });
  }
}
