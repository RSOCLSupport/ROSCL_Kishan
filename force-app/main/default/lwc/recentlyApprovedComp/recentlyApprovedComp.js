import { LightningElement } from 'lwc';
import getRecentlyApprovedReq from '@salesforce/apex/RSOCL_ApprovalProcessedDataController.getProcessedAprrovalRecords';
import { NavigationMixin } from 'lightning/navigation';

export default class RecentlyApprovedComp extends NavigationMixin (LightningElement) {
    
    sortedDirection;
    sortedColumn;
    data;
    recordIdStr;
    recordObjApiName;
    tableDataArray = [];
    _expendedObjectsMap = {};
    nameUpBool;
    nameDWBool;
    objUpBool;
    objDWBool;
    dateUpBool;
    dateDWBool;
    showSpinner = false;
    _currentApprovedStatus;
    showNoRecordsToDisplay = false;


    connectedCallback(){
        console.log('IN connectedCallback...........');
        this.showSpinner = true;
        getRecentlyApprovedReq().then(result => {
            console.log('result#'+result.length);
            this.data = result;
            if (this.data && this.data?.length > 0) {
                this.data.forEach(row => {
                    var index = this.tableDataArray.findIndex(x => x.status == row.approvedStatus);
                    if (index > -1)
                        this.tableDataArray[index].childRecords.push(row);
                    else
                        this.tableDataArray.push({
                            status: row.approvedStatus,
                            rowColor:row.rowColor,
                            childRecords: new Array(row)
                        });
                })
                this.sortedColumn = 'recordName';
                this.sortRecs();
            }
            else{
                this.showNoRecordsToDisplay = true;
            }
            this.showSpinner = false;
            console.log('tableDataArray**',JSON.stringify(this.tableDataArray));
        })
        .catch(error => {
            console.log('error#'+error);
            this.data = undefined;
            this.showSpinner = false;

        });
    }

    handleChildRowDisplayAction(event) {
        this.showSpinner = true;
        var id = event.target.dataset.id;
        console.log('id***',id);
        var displayProp = event.target.dataset.val;
        console.log('displayProp***',displayProp);

        if (id){
            this._expendedObjectsMap[id] = (displayProp == 'show' ? true : false);
        }
        console.log('_expendedObjectsMap[id]***',JSON.stringify(this._expendedObjectsMap)); 
        console.log('_expendedObjectsMap[id]***',this._expendedObjectsMap[id]);   
        this.showSpinner = false;
    }

    get getTableData() {
        console.log('IN getTableData......');
        this.tableDataArray.forEach(row => {
            console.log('status***', row.status);
            console.log('isExpended***',this._expendedObjectsMap[row.status]);
        })

        var processedData =  (this.tableDataArray.map((row, index) =>
        ({
            ...row,
            isExpended: this._expendedObjectsMap[row.status],
            totalChildRecordCount: row.childRecords?.length
        })));
        console.log('processedData***', JSON.stringify(processedData));
        return processedData;

    }

    navigateToRecDetailsPage(event){
        this.recordObjApiName  = event.currentTarget.dataset.type;
        this.recordIdStr  = event.currentTarget.dataset.val;
        console.log('recordIdStr***',this.recordIdStr);
        console.log('recordObjApiName***',this.recordObjApiName);
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

    sortRecs( event ) {
        console.log('IN SORTRECS,,,,,,,,,,,,')
        if(event){
            this._currentApprovedStatus = event.target.dataset.type;
        }
        this.nameUpBool = false;
        this.nameDWBool = false;
        this.dateUpBool = false;
        this.dateDWBool = false;
        this.objUpBool = false;
        this.objDWBool = false;

        let colName = event ? event.target.name : undefined;
        console.log( 'Column Name is ',colName );
        console.log('sortedColumn***',this.sortedColumn);
        console.log('sortedDirection***',this.sortedDirection);
        if ( this.sortedColumn === colName )
            this.sortedDirection = ( this.sortedDirection === 'asc' ? 'desc' : 'asc' );
        else
            this.sortedDirection = 'asc';
        
        console.log('sortedDirection->>>>>',this.sortedDirection);
        let isReverse = this.sortedDirection === 'asc' ? 1 : -1;

        if ( colName )
            this.sortedColumn = colName;
        else
            colName = this.sortedColumn;

        switch ( colName ) {

            case "recordName":
            if ( this.sortedDirection == 'asc' )
                this.nameUpBool = true;
            else
                this.nameDWBool = true;
            
            break;

            case "relatedTo":
            if ( this.sortedDirection == 'asc' )
                this.objUpBool = true;
            else
                this.objDWBool = true;
            
            break;

            case "approvedDate":
            if ( this.sortedDirection == 'asc' )
                this.dateUpBool = true;
            else
                this.dateDWBool = true;
            
            break;
        }
		var data = [...this.tableDataArray];
        if(event){
            console.log('FRom an Event')
            data.forEach(row => {
                if(row.status === this._currentApprovedStatus){
                    console.log('Current status is Matching..')
                    row.childRecords = JSON.parse(JSON.stringify(row.childRecords)).sort(( a, b ) => {
                        a = a[ colName ] ? a[ colName ].toLowerCase() : 'z'; 
                        b = b[ colName ] ? b[ colName ].toLowerCase() : 'z';
                        return a > b ? 1 * isReverse : -1 * isReverse;
                    });
                }
            })
        }
        else{
            console.log('Not an Event')
            data.forEach(row => {
                row.childRecords = JSON.parse(JSON.stringify(row.childRecords)).sort(( a, b ) => {
                    a = a[ colName ] ? a[ colName ].toLowerCase() : 'z'; 
                    b = b[ colName ] ? b[ colName ].toLowerCase() : 'z';
                    return a > b ? 1 * isReverse : -1 * isReverse;
                });  
            })
        }
		this.tableDataArray = data;
    }

}